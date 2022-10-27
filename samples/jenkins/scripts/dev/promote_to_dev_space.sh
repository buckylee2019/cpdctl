export PATH=$PATH:$PWD

#
# Expected environment variables:
#
# $PROJECT_ID - ID of the source project
# $DEV_SPACE_ID - ID of the development deployment space
#

env_name=jupconda38
job_name=train-scikit-model-job
trained_model_id_file=./trained_model_id
software_specification_name='runtime-22.1-py3.9'

export CPD_SCOPE=cpd://cpd402-demo/projects/$PROJECT_ID

find_asset () {
  echo "Searching for $1 with name: $2..." >&2
  asset_id=$(cpdctl asset search --type-name $1 --query "asset.name:$2" \
    --output json --jmes-query "results[0].metadata.asset_id" --raw-output)
  echo "Found: $asset_id" >&2
  echo $asset_id
}

promote_asset () {
  echo "Promoting $1 with ID: $2 to development space $DEV_SPACE_ID..." >&2
  promote="{\"space_id\": \"$DEV_SPACE_ID\"}"
  cpdctl asset promote --asset-id $2 --request-body "$promote"
}

trained_model_id=$(<${trained_model_id_file})
regression_data_asset_id=$(find_asset data_asset "credit_risk_regression.csv")
evaluation_script_id=$(find_asset script "evaluate_model*")

software_id=$(cpdctl environment software-specification list --space-id "$DEV_SPACE_ID" --name "$software_specification_name" --output json --jmes-query 'resources[0].metadata.asset_id' --raw-output)

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

# cpdctl asset attribute update --space-id "$DEV_SPACE_ID" --asset-id "$evaluation_script_id" --attribute-key script  --json-patch '@./softwarespec.json'




promote_asset "trained model" $trained_model_id
promote_asset "regression data asset" $regression_data_asset_id
promote_asset "evaluation script" $evaluation_script_id

cpdctl asset attribute update --space-id "$DEV_SPACE_ID" --asset-id "$evaluation_script_id" --attribute-key script  --json-patch '@./softwarespec.json'

export CPD_SCOPE=cpd://cpd402-demo/spaces/$DEV_SPACE_ID

cpdctl asset search --query '*:*' --type-name asset
