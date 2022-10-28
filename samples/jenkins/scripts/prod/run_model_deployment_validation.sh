export PATH=$PATH:$PWD

#
# Expected environment variables:
# $PROD_SPACE_ID - ID of the production deployment space
#

export CPD_SCOPE=cpd://cpd402-demo/spaces/$PROD_SPACE_ID
export_file=./evaluation_result.zip
evaluation_output_name=model_evaluation_result.zip
job_name='evaluate_model_batch_deployment_job'
results_path='job_results.zip'
find_asset () {
  echo "Searching for $1 with name: $2..." >&2
  asset_id=$(cpdctl asset search --type-name $1 --query "asset.name:$2" \
    --output json --jmes-query "results[0].metadata.asset_id" --raw-output)
  echo "Found: $asset_id" >&2
  echo $asset_id
}


imported_regression_data_asset_id=$(find_asset data_asset "credit_risk_regression.csv" $PROD_SPACE_ID)
prod_evaluation_script_id=$(find_asset script "evaluate_model*")
prod_model_id=$(cpdctl asset search --query '*:*' --type-name wml_model --output json \
  --jmes-query "results[0].metadata.asset_id" --raw-output)
evaluate_model_job_id=$(find_asset job "evaluate_model_job")

if [ "$evaluate_model_job_id" == "null" ]
then
script_batch_deployment_id=$(cpdctl ml deployment list --space-id "$PROD_SPACE_ID" --asset-id "$prod_model_id"  --output json --jmes-query 'resources[0].metadata.id' --raw-output)

# echo "Script Batch Deploy id: $script_batch_deployment_id"
# cat > scoring.json <<-EOJSON
#  {
#     "input_data_references": [
#       {
#         "type": "data_asset",
#         "id": "input",
#         "connection": {},
#         "location": {
#           "href": "/v2/assets/$imported_regression_data_asset_id?space_id=$PROD_SPACE_ID"
#         }
#       }
#     ],
#     "output_data_reference": {
#       "type": "data_asset",
#       "id": "output",
#       "connection": {},
#       "location": {
#         "name": "$evaluation_output_name"
#       }
#     }
# }
# EOJSON

cat > scoring.json <<-EOJSON
 {
    "input_data_references": [
      {
        "type": "data_asset",
        "id": "input",
        "connection": {},
        "location": {
          "href": "/v2/assets/$imported_regression_data_asset_id?space_id=$PROD_SPACE_ID"
        }
      }
    ],
    "output_data_reference": {
      "type": "data_asset",
      "id": "output",
      "connection": {},
      "location": {
        "name": "$evaluation_output_name"
      }
    }
}
EOJSON

echo "Starting job $job_name..."

deployment_script_job_id=$(cpdctl ml deployment-job create wait --space-id "$test_space_id" --name "$job_name" \
  --deployment '{"id": "'$script_batch_deployment_id'"}' --scoring '@./scoring.json' --output json -j "metadata.id" \
  --raw-output)

while [[ "$job_id" == "" || "$job_id" == "null" ]]; do
  deployment_job=$(cpdctl ml deployment-job get --space-id "$PROD_SPACE_ID" --job-id "$deployment_script_job_id" \
    --output json)

  job_id=$(echo $deployment_job | jq '.entity.platform_job.job_id' -r)
  run_id=$(echo $deployment_job | jq '.entity.platform_job.run_id' -r)

  sleep 1
done

echo "Run: $run_id started for a job: $job_id..."

cpdctl job run wait --job-id "$job_id" --run-id "$run_id" --space-id "$PROD_SPACE_ID"

output_data_asset_id=$(cpdctl asset search --space-id "$PROD_SPACE_ID" --type-name data_asset \
  --query "$evaluation_output_name" --output json --jmes-query "results[0].metadata.asset_id" --raw-output)

echo "Results : $output_data_asset_id for a run: $run_id..."

results_attachment_id=$(cpdctl asset get --space-id "$PROD_SPACE_ID" --asset-id "$output_data_asset_id" \
  --output json --jmes-query "attachments[-1].id" --raw-output)

echo "Downloading: $evaluation_output_name to the $results_path..."

cpdctl asset attachment download --space-id "$PROD_SPACE_ID" --asset-id "$output_data_asset_id" \
  --attachment-id "$results_attachment_id" --output-path "$results_path"

echo "Unziping $results_path to results.txt"

unzip -p "$results_path" results.txt