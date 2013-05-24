#!/bin/bash
#
# This script pulls config vars from a "localrc" shell script,
#  then launches an instance in EC2 based on those values,
#  which then bootstraps a build using the "user-data" field 
#   plus cloud-init.
#
# This script outputs the ID of the instance started.
#

source include/functions.sh
LOCALRC=${1:-localrc}
source ${LOCALRC}


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

debug Command "${CMD}"

#
# Run the command, parsing the output (stupid Amazon command line!)
#
run_results=$( $CMD )
inst_id=$( get_instance_id $run_results )

debug "Command Output" "${run_results}"
debug "User Data File" "${USER_DATA_FILE}"

rm -f ${USER_DATA_FILE}

#
# Report the instance ID
#
echo $inst_id

 

