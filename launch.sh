#!/bin/bash
#
# This script pulls config vars from a "localrc" shell script,
#  then launches an instance in EC2 based on those values,
#  which then bootstraps a build using the "user-data" field 
#   plus cloud-init.
#
# This script outputs the ID of the instance started.
#

source include/functions-local.sh
LOCALRC=${1:-localrc}
source ${LOCALRC}

#
# Create a role and policy so that instances
#   can access data on a given S3 bucket
#
# NOT ENABLED FOR NOW
#
#ROLE=dev-access
#BUCKET=${DATA_S3_BUCKET} # Needs to be set in localrc
#
#profile_name=$( create_s3_access_role ${ROLE} ${BUCKET} )
#


#
# Provision private data files
#
DATA_URLS=$( provision_private_data "${PRIVATE_DATA_URLS}" )
debug "S3 new URLS" ${DATA_URLS}

# 
# Create an RDS instance 
#
if [ "y" = "${USE_RDS}" ]; then 
	MYSQL_ADMIN_URI=$( create_rds_mysql_instance )
fi

[ -z "${MYSQL_ADMIN_URI}" ] || debug "Setup new RDS MySQL instance at \"${MYSQL_ADMIN_URI}\""

#
# Create a user-data file to provide to the instance
#  This file, in this case a shell script, will be
#  handed off to the "cloud-init" bootstrap system
#
USER_DATA_FILE=$( make_user_data ${LOCALRC} ${BOOTSTRAP} )

#
# Now actually run the instance
#
CMD="ec2-run-instances ${EC2_AMI} \
 --key  ${EC2_KEYNAME} \
 --group ${EC2_SECURITY_GROUP} \
 --instance-type ${EC2_INSTANCE_TYPE} \
 --user-data-file ${USER_DATA_FILE} "

#[ -n ${profile_name} ] && CMD="${CMD} --iam-profile ${profile_name}"

debug Command "${CMD}"

#
# Run the command, parsing the output,
#  and report the instance ID
#
run_results=$( $CMD )
inst_id=$( get_instance_id $run_results )
echo $inst_id

debug "Command Output" "${run_results}"
#debug "User Data File" "${USER_DATA_FILE}"

rm -f ${USER_DATA_FILE}
