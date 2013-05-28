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
			errecho $2 >2 
		fi
		errecho "----------------------------------------" >2 
	fi
}

#
# Assemble a user_data file for EC2 from parts.
#
function make_user_data {
	local localrc=$1
	local bootstrap=$2
	mkdir tmp 2>/dev/null 
	tmpf=$(mktemp user-data-script.sh.XXXXXX)
	echo "#!/bin/bash"        >> ${tmpf}
	cat ${localrc}            >> ${tmpf}
	cat include/functions.sh  >> ${tmpf}
	cat ${bootstrap}          >> ${tmpf}
	echo ${tmpf}
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
	
		
#
# Prepare a RHEL-ish v6 instance for puppetization
#
#
# Install basics to bootstrap this process
#
function prepare_rhel6_for_puppet {
	
	local extra_pkgs=$1
	
	# Get EPEL installed
	EPEL_RPM=http://mirror.utexas.edu/epel/6/i386/epel-release-6-8.noarch.rpm
	if ! [ -f /etc/yum.repos.d/epel.repo ]; then
		rpm -ihv ${EPEL_RPM} || /bin/true		
	fi
	
	export PATH="${PATH}:/usr/local/bin"
	PKGS="puppet git curl ${extra_pkgs}"
	yum -y install ${PKGS}
	
	echo $( facter operatingsystem )
	# to convince puppet we're a RHEL derivative, and then get EPEL installed
	[ -f /etc/system-release ] && cp -af /etc/system-release /etc/redhat-release 
		
}

#
# pull repo with git
#
function git_pull {
	
	local repo=$1
	local branch=$2
	
	if ! [ x = "x${branch}" ]; then 
		branch_arg="--branch $branch"
	fi
git clone ${branch_arg} $repo 
	dir=$( echo ${repo} | awk -F/ '{print $NF}' | sed 's/\.git//' )
	cd ${dir}
	
	git submodule sync || /bin/true
	git submodule update --init  || /bin/true
	
	echo
}
	