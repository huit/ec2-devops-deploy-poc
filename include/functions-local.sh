#
# Various helper functions to make or code cleaner 
#

#
# Convenience function to
#  print out stuff

function errecho { echo "$@" 1>&2; }
function debug {
	if [ $DEBUG = "y" ]; then
		errecho "$1:"
		errecho "----------------------------------------"
		if [ -r "$2" ]; then 
			cat $2 1>&2
		else
			errecho $@ >2 
		fi
		errecho "----------------------------------------" >2 
	fi
}

#
# Create a role that allows the instance
#  to access objects in a given bucket
#
# See: 
#     - http://www.greenhills.co.uk/2012/12/25/s3cmd-with-iam-roles.html
# 	  - https://forums.aws.amazon.com/message.jspa?messageID=404615
#

function create_s3_access_role {
	
	local role=$1
	local bucket=$2
	
	local bucket2=$( echo ${bucket} | sed 's/\./-/g' )
	local policy=${role}-${bucket2}-policy
	local iprofile=${role}-${bucket2}-inst-profile

	tmpf=$(mktemp policy.XXXXXX)
	cat <<EOF > ${tmpf}
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:Get*",
        "s3:List*",
        "s3:Put*"
      ],
      "Resource": "arn:aws:s3:::${bucket}"
    }
  ]
}
EOF

	cmd="iam-rolecreate -r ${role} -p / -s ec2.amazonaws.com -v"
	debug ${cmd}
	${cmd} > /dev/nullv 2>&1
	
	cmd="iam-roleuploadpolicy -r ${role} -p ${policy} -f $tmpf " 
	debug ${cmd}
	${cmd} > /dev/null 2>&1
		
	cmd="iam-instanceprofilecreate -p / -r ${role} -s ${iprofile} " 
	debug ${cmd}
	${cmd} > /dev/null 2>&1
	
	
	rm -f ${tmpf}
	
	echo ${iprofile}
}
	

					
#
# Assemble a user_data file for EC2 from parts.
#
function make_user_data {
	local localrc=$1
	local bootstrap=$2
	mkdir tmp 2>/dev/null 
	tmpf=$(mktemp user-data-script.sh.XXXXXX)
	
	echo "#!/bin/bash"        	  	  >> ${tmpf}
	cat ${localrc}                    >> ${tmpf}
	echo "DATA_URLS=\"${DATA_URLS}\"" >> ${tmpf}
	cat include/functions-remote.sh   >> ${tmpf}
	cat ${bootstrap}          	      >> ${tmpf}
	
	echo ${tmpf}
}

#
# Returns a unique random (enough) ID
#
function create_uuid {
	uuidgen
}

#
# Given a target set of S3 URLs, provisions
#  
function provision_private_data {
	
	local s3_urls=$1
	local new_urls=""
			
	if [ -n "$s3_urls" ]; then
		
		local uuid=$( create_uuid )

		for url in $s3_urls; do
		
			local bucket=$(   echo $url | awk -F/ '{print $3}' )
			local filename=$( echo $url | awk -F/ '{print $NF}' )
		
			local new_url="s3://${bucket}/${uuid}/${filename}"
			local new_resource="arn:aws:s3:::${bucket}/${uuid}/${filename}"	
			local new_public_url="https://s3.amazonaws.com/${bucket}/${uuid}/${filename}"
			
			# Make a copy of the data
			s3cmd cp ${url} ${new_url} > /dev/null 2>&1
			s3cmd setacl ${new_url} --acl-public  > /dev/null 2>&1
			s3cmd setacl s3://${bucket}  --acl-private > /dev/null 2>&1

			# Set permissions on that data to allow get and delete
			#			tmpf=$(mktemp policy.XXXXXX)
			#			cat <<EOF > ${tmpf}
#{
#  "Version":"2008-10-17",
#  "Statement":[{
#	"Sid":"AddPerm",
#        "Effect":"Allow",
#	  "Principal": {
#            "AWS": "*"
#         },
#     "Action":["s3:GetObject","s3:DeleteObject"],
#     "Resource":["${new_resource}"
#      ]
#    }
# ]
#}
#EOF
			
			new_urls="${new_urls} ${new_public_url}"
		done
	fi
	
	echo ${new_urls}
}	
	
function get_instance_id {
	local runres=$1
	echo $run_results | grep INSTANCE | sed 's/.*INSTANCE *//' | awk '{print $1}'
}
	
function get_instance_hostname {
	local inst_id=$1
	hname=$( ec2-describe-instances ${inst_id} | grep INSTANCE | awk '{print $4}' )
	echo $hname
}

function create_rds_mysql_instance {
	
	local inst_id="db$( create_uuid | sed 's/-//g' )"
	local storage=10 #GB
	local class=db.m1.small
	local passwd=$( create_uuid | sed 's/-//g' )	
	
	local cmd="rds-create-db-instance ${inst_id} \
		--allocated-storage  ${storage}  \
		--db-instance-class  ${class} \
		--engine  mysql \
		--master-user-password  ${passwd} \
		--master-username root \
		--db-name  ${inst_id}"

	errecho	$cmd
	$cmd > /dev/null
		
	# wait for a hostname to be established	
	hostname="(nil)"
	while [ "(nil)" = "${hostname}" ]; do
		sleep 5 
		echo Checking if database instance ${inst_id} has a hostname ...
		result=$( rds-describe-db-instances ${inst_id} --show-long | grep DBINSTANCE )
		hostname=$( echo $result | awk -F, '{print $10}' )
	done

	local connection_string="mysql://root:${passwd}@${hostname}/${inst_id}"
      
    errecho  ${connection_string}
    echo ${connection_string}
}
