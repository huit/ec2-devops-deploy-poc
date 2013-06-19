#
# Required packages for bootstrapped system	
#
REQUIRED_PKGS="puppet git curl wget s3cmd aws-cli ruby-devel rubygems gcc"
	
#
# Prepare a RHEL-ish v6 instance for puppetization
#
# Install basics to bootstrap this process
# This includes:
#          - ruby
#          - puppetlabs yum repo
#          - puppet
#          - r10k
#          - git
#          - wget & curl
#          - s3cmd line tools
# 
function prepare_rhel6_for_puppet {
	
	local extra_pkgs=$1
	
	# Get the puppet labs repo installed
	rpm -ivh http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-7.noarch.rpm
	
	# Get EPEL installed
	EPEL_RPM=http://mirror.utexas.edu/epel/6/i386/epel-release-6-8.noarch.rpm
	if ! [ -f /etc/yum.repos.d/epel.repo ]; then
		rpm -ihv ${EPEL_RPM} || /bin/true		
	fi
	
	# We need to disable yum priorities, because of the stupid Amazon repo priorities 
	#  prevent getting latest puppet
	export PATH="${PATH}:/usr/local/bin"
	PKGS="${REQUIRED_PKGS} ${extra_pkgs}"
	yum -y --enablerepo=epel --disableplugin=priorities install ${PKGS}
	
	# install r10k using gem
	gem install r10k
	
	echo $( facter operatingsystem )
	# to convince puppet we're a RHEL derivative, and then get EPEL installed
	[ -r /etc/redhat-release ] || echo "CentOS release 6.4 (Final)" > /etc/redhat-release
	#	[ -f /etc/system-release ] && cp -af /etc/system-release /etc/redhat-release 
		
}

# Run puppet on a suitable repo
function do_puppet {
	
	local site_file=${1:-manifests/site.pp}
	
	#r10k deploy environment --puppetfile Puppetfile
	if [ -r Puppetfile ]; then
			HOME=/root r10k puppetfile install
	fi
	puppet apply ${site_file}  --modulepath=./modules
	
}
#
# On the server side, pull down any credentials
#   setup for this instance, and build appropriate
#   config files
#
# CURRENTLY NOT USED: client are not yet mature enough to use proxy creds.
#
function setup_aws_creds {
	
	local role=$( wget -O - -q "http://169.254.169.254/latest/meta-data/iam/security-credentials/" )
	wget -O - -q "http://169.254.169.254/latest/meta-data/iam/security-credentials/${role}" > /tmp/s3-creds.txt
	
	# Parse the output
	access_key=$( grep AccessKeyId /tmp/s3-creds.txt | awk -F:  '{print $2}' | sed 's/\"//g' | sed 's/,//' )
	secret_key=$( grep SecretAccessKey /tmp/s3-creds.txt | awk -F:  '{print $2}' | sed 's/\"//g' | sed 's/,//' )
	token=$( grep Token /tmp/s3-creds.txt | awk -F:  '{print $2}' | sed 's/\"//g' | sed 's/,//' )	

	# make a config file for the s3cmd client
	rm -f ~/.s3cfg
	echo "access_key = ${access_key}" >>  ~/.s3cfg
	echo "secret_key = ${secret_key}" >>  ~/.s3cfg
	
	# Make a credential file for the "aws" command line client
	rm -f ~/.awssecret
	echo ${access_key} >>  ~/.awssecret
	echo ${secret_key} >>  ~/.awssecret

	# Make a simple shell script
	rm -f ~/.s3.sh	
	echo "AWS_ACCESS_KEY_ID=${access_key}" >> ~/.s3.sh
	echo "AWS_SECRET_ACCESS_KEY=${secret_key}" >> ~/.s3.sh 
	echo "TOKEN=${token}" >> ~/.s3.sh 
	
}
	
#
# Pull private data from S3
#	Takes a set of urls as an argument,
#   and leaves a set of files/dirs in current directory
#
function pull_private_data {
	local urls=$@
	
	for url in $urls; do	
		protocol=$( echo $url | awk -F: '{print $1}' )
	
		if [ 'https' = "${protocol}" ]; then
			wget -q ${url}
		fi	
		
		if [ 'git' = "${protocol}" ]; then
			git clone ${url}
		fi				
	
		if [ 's3' = "${protocol}" ]; then
			local fname=$(  echo $url | awk -F/ '{print $NF}' )
			s3cmd get ${url} ${fname}
		fi	
	done
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
	