#
# Various helper functions to make or code cleaner
#

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
	
#
# Prepare a RHEL-ish v6 instance for puppetization
#
#
# Install basics to bootstrap this process
#
function prepare_rhel6_for_puppet {
	
	local extra_pkgs=$1
	
	# to convince puppet we're a RHEL derivative, and then get EPEL installed
	[ -f /etc/system-release ] && cp -af /etc/system-release /etc/redhat-release 
	
	# to convince puppet we're a RHEL derivative, and then get EPEL installed
	EPEL_RPM=http://mirror.utexas.edu/epel/6/i386/epel-release-6-8.noarch.rpm
	rpm -ihv ${EPEL_RPM} || /bin/true		
	
	export PATH="${PATH}:/usr/local/bin"
	PKGS="puppet git curl ${extra_pkgs}"
	yum -y install ${PKGS}
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
	