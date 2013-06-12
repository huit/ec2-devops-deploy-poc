#!/bin/bash
# 
# This bootstrap script uses puppet 
#  to setup a Jenkins instance
#
# assumes the following bash vars are defined:
#
#  - PUPPET_REPO_URL
#  - PUPPET_REPO_BRANCH
#
#  - REPO_URL
#  - REPO_BRANCH
#

#  - EXTRA_PKGS (optional)

ANSWERS_FILE=/root/answers.txt

#---------------------------------
#  Build and configure PLATFORM
#---------------------------------

prepare_rhel6_for_puppet "${EXTRA_PKGS}"

#
# Setup RDO repos
#
yum install -y http://rdo.fedorapeople.org/openstack/openstack-grizzly/rdo-release-grizzly.rpm
yum install -y openstack-packstack openstack-utils
	
#
# Setup ssh key based local access for root
#
perl -i -p -e 's/^PermitRootLogin .*/PermitRootLogin yes/g' /etc/ssh/sshd_config 
service sshd restart 
cd /root/.ssh && rm -f id_rsa* && ssh-keygen -f id_rsa -t rsa -N '' && cat id_rsa.pub >> authorized_keys 	
												
#                                                                                                                                                                                         
# pull & setup the puppet modules and run manifest
cd /tmp
git_pull ${PACKSTACK_REPO_URL} ${PACKSTACK_REPO_BRANCH}
#do_puppet ./manifests/site.pp
export HOME=/root
./bin/packstack --gen-answer-file=${ANSWERS_FILE}

# Any edits go here ....
echo "checking for openstack-config command ....."
which openstack-config
rpm -ql openstack-utils

CONFIG="/usr/bin/openstack-config --set ${ANSWERS_FILE} "

# Use Swift & https
${CONFIG} general CONFIG_SWIFT_INSTALL y
${CONFIG} general CONFIG_HORIZON_SSL y

#
# If we are on EC2, we need to tweak this sucker ...
#
EC2_PUBLIC_IP=$(facter ec2_public_ipv4)

if ! [ -z $EC2_PUBLIC_IP ]; then

	# edit to use public IPs for endpoints for services that need to be accessed from outside.
	KEYS=" CONFIG_KEYSTONE_HOST \
           CONFIG_GLANCE_HOST \
           CONFIG_CINDER_HOST \
           CONFIG_HORIZON_HOST \
           CONFIG_QUANTUM_SERVER_HOST \
           CONFIG_NOVA_VNCPROXY_HOST \
           CONFIG_NOVA_API_HOST \
           CONFIG_NOVA_COMPUTE_HOSTS \
           CONFIG_NOVA_CERT_HOST \
           CONFIG_NOVA_SCHED_HOST \
           CONFIG_SWIFT_PROXY_HOSTS"
    
	for KEY in $KEYS; do 
		${CONFIG} general ${KEY} ${EC2_PUBLIC_IP}
	done

	# Fix the interface for a single-node installation (use loopback)
	${CONFIG} general CONFIG_NOVA_COMPUTE_PRIVIF lo
	${CONFIG} general CONFIG_NOVA_NETWORK_PRIVIF lo
fi

./bin/packstack --answer-file=${ANSWERS_FILE}


#
# WIP on getting quantum happy. See the following
#
#   - http://openstack.redhat.com/forum/discussion/143/rdo-quantum-networking-form-a-grassroots-effort-to-get-this-into-rdo
#   - https://fedoraproject.org/wiki/Packstack_to_Quantum
#
#

#
# Make some objects in the system, including images
#  
cd /tmp
git_pull ${OPENSTACK_POST_SCRIPTS_REPO_URL} ${OPENSTACK_POST_SCRIPTS_REPO_BRANCH}
bash ./main.sh

#do_puppet ./manifests/site.pp
