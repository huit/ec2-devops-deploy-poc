#!/bin/bash
#
# This script ssh's to the specified instance

source include/functions-local.sh

if [ -z $1 ]; then
	echo $( basename $0 ): Must specify instance ID.
	exit 1
fi

inst_id=$1
hname=$( get_instance_hostname ${inst_id} )

url="http://${hname}/"

if [ -z ${hname} ]; then
	echo No hostname for instance id "${inst_id}".
	exit
fi

CMD="echo Platform not yet supported ..."

if [ "Darwin" = "$( uname -a  | awk '{print$1}' )" ]; then
	CMD="open ${url}"
fi

exec ${CMD}

