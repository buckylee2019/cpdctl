export PATH=$PATH:$PWD

#
# Expected environment variables:
# $PROD_SPACE_ID - ID of the production deployment space
#

export CPD_SCOPE=cpd://cpd402-demo/spaces/$PROD_SPACE_ID
export_file=./evaluation_result.zip
evaluation_output_name=model_evaluation_result.zip
job_name='evaluate_model_batch_deployment_job'

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

echo "Starting job $job_name..."

# deployment_script_job_id=$(cpdctl ml deployment-job create wait --space-id "$PROD_SPACE_ID" --name "$job_name" \
#   --deployment '{"id": "'$script_batch_deployment_id'"}' --scoring '@./scoring.json' --output json -j "metadata.id" \
#   --raw-output)
job_id=$(cpdctl ml deployment-job list --deployment-id "$script_batch_deployment_id" --space-id "$PROD_SPACE_ID" --output json --jmes-query 'resources[0].entity.platform_job.job_id' --raw-output)

evaluate_model_job_id=$job_id
fi
software_specification_name='runtime-22.1-py3.9'
software_id=$(cpdctl environment software-specification list --space-id "$PROD_SPACE_ID" --name "$software_specification_name" --output json --jmes-query 'resources[0].metadata.asset_id' --raw-output)

cat > softwarespec.json <<-EOJSON
[
  {
    "op": "add",
    "path": "/software_spec",
    "value": {
    "base_id": "$software_id",
    "name": "$software_specification_name"
  }
}
]
EOJSON

cpdctl asset attribute update --space-id "$PROD_SPACE_ID" --asset-id "$prod_evaluation_script_id" --attribute-key script  --json-patch '@./softwarespec.json'

echo "Run starting for a job: $evaluate_model_job_id..."
run_id=$(cpdctl job run create --space-id "$PROD_SPACE_ID" --job-id "$job_id" --job-run '{}' --output json --jmes-query '{jmes_query}' --raw-output)
#cpdctl job run create --job-id "$evaluate_model_job_id" --job-run '{}' --space-id $PROD_SPACE_ID
cpdctl job run wait --job-id "$evaluate_model_job_id" --run-id "$run_id" --space-id "$PROD_SPACE_ID"
echo "Finish running!"
results_asset_id=$(find_asset data_asset "evaluation_result.zip")

results_attachment_id=$(cpdctl asset get --asset-id $results_asset_id --output json --jmes-query "attachments[-1].id" --raw-output)

echo "Downloading: evaluation_result.zip to the $export_file..."

cpdctl asset attachment download --asset-id "$results_asset_id" --attachment-id "$results_attachment_id" --output-path "${export_file}"

echo "Unziping $export_file"

unzip -p ${export_file}
