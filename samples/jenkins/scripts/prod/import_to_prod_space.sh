export PATH=$PATH:$PWD

#
# Expected environment variables:
# $PROD_SPACE_ID - ID of the production deployment space
#

export_file=./test-space-assets.zip

export CPD_SCOPE=cpd://cpd402-demo/spaces/$PROD_SPACE_ID

ls -al
unzip -l ${export_file}

cpdctl asset import start --import-file ${export_file}
