#!/bin/bash
#
# This script pulls config vars from a "localrc" shell script,
#  then launches an instance in EC2 based on those values,
#  which then bootstraps a build using the "user-data" field 
#   plus cloud-init.
#
# This script outputs the ID of the instance started.
#

# Convenience function to
#  print out stuff
function debug {
	if [ $DEBUG = "y" ]; then
		echo "$1:"
		echo "----------------------------------------"
		if [ -r "$2" ]; then 
			cat $2
		else
			echo $2
		fi
		echo "----------------------------------------"
	fi
}

# The actual settings

source localrc


#
# Create a user-data file to provide to the instance
#  This file, in this case a shell script, will be
#  handed off to the "cloud-init" bootstrap system
#
mkdir tmp 2>/dev/null 
TMPFILE=$(mktemp user-data-script.sh.XXXXXX)
echo "#!/bin/bash" >> ${TMPFILE}
cat localrc ${BOOTSTRAP} >> ${TMPFILE}

#
# Now actually run the instance
#
CMD="ec2-run-instances ${EC2_AMI} \
 --key  ${EC2_KEYNAME} \
 --group ${EC2_SECURITY_GROUP} \
 --instance-type ${EC2_INSTANCE_TYPE} \
 --user-data-file ${TMPFILE} "

debug Command "${CMD}"

#
# Run the command, parsing the output (stupid Amazon command line!)
#
run_results=$( $CMD )
inst_id=$( echo $run_results | grep INSTANCE | sed 's/.*INSTANCE *//' | awk '{print $1}' )

debug "Command Output" "${run_results}"
debug "User Data File" "${TMPFILE}"

rm -f ${TMPFILE}

#
# Report the instance ID
#
echo $inst_id

 

