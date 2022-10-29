export PATH=$PATH:$PWD

#
# Expected environment variables:
#

test_space_id_file=./test-space-id
export_file=./test-space-assets.zip
test_space_id=$(<${test_space_id_file})

export CPD_SCOPE=cpd://cpd402-demo/spaces/$test_space_id

# TODO: replace the below code with:
# cpdctl asset export start --assets '{"all_assets": true}' --name dev-space-all-assets --output-file "$export_file"
# when https://github.ibm.com/AILifecycle/tracker/issues/2228 is fixed

cpdctl asset export start --assets '{"all_assets": true}' --name test-space-all-assets
export_id=$(cpdctl asset export list --output json --jmes-query 'resources[-1].metadata.id' --raw-output)
cpdctl asset export download --export-id ${export_id} --output-file "${export_file}"

unzip -t ${export_file}


echo Cleaning up the test space ${test_space_id}...

cpdctl space delete --space-id ${test_space_id}

echo Done!
