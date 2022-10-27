export PATH=$PATH:$PWD

#
# Expected environment variables:
# $PROD_SPACE_ID - ID of the production deployment space
#

export CPD_SCOPE=cpd://cpd402-demo/spaces/$PROD_SPACE_ID
export_file=./evaluation_result.zip

find_asset () {
  echo "Searching for $1 with name: $2..." >&2
  asset_id=$(cpdctl asset search --type-name $1 --query "asset.name:$2" \
    --output json --jmes-query "results[0].metadata.asset_id" --raw-output)
  echo "Found: $asset_id" >&2
  echo $asset_id
}

prod_evaluation_script_id=$(find_asset script "evaluate_model*")

evaluate_model_job_id=$(find_asset job "evaluate_model_job")
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

cpdctl job run create --job-id "$evaluate_model_job_id" --job-run '{}'

results_asset_id=$(find_asset data_asset "evaluation_result.zip")

results_attachment_id=$(cpdctl asset get --asset-id $results_asset_id --output json --jmes-query "attachments[-1].id" --raw-output)

echo "Downloading: evaluation_result.zip to the $export_file..."

cpdctl asset attachment download --asset-id "$results_asset_id" --attachment-id "$results_attachment_id" --output-path "${export_file}"

echo "Unziping $export_file"

unzip -p ${export_file}
