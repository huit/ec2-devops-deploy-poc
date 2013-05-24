#!/bin/bash
#
# This script ssh's to the specified instance

source include/functions.sh
REMOTE_USER=ec2-user

if [ -z $1 ]; then
	echo $( basename $0 ): Must specify instance ID.
	exit 1
fi

inst_id=$1
hname=$( get_instance_hostname ${inst_id} )

if [ -z ${hname} ]; then
	echo No hostname for instance id "${inst_id}".
	exit
fi

CMD="ssh -o StrictHostKeyChecking=no  -l ${REMOTE_USER} ${hname}"

exec ${CMD}

