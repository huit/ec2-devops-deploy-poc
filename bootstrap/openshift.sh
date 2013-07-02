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

#---------------------------------
#  Build and configure PLATFORM
#---------------------------------

prepare_rhel6_for_puppet ${EXTRA_PKGS}

#
# Configs from the OpenShift Origin docs at
#
#   http://openshift.github.io/origin/file.install_origin_using_puppet.html
#
yum -y install bind

# Generate the TSIG Key
# Using example.com as the cloud domain
CLOUD_DOMAIN=example.com

rm -f /var/named/K${CLOUD_DOMAIN}*.key /var/named/K${CLOUD_DOMAIN}*.private

/usr/sbin/dnssec-keygen \
	-a HMAC-MD5 \
	-b 512 \
	-n USER \
	-r /dev/urandom \
	-K /var/named \
	${CLOUD_DOMAIN}
TSIG_KEY=$(  cat /var/named/Kexample.com.*.key  | awk '{print $8}' )
rm -f /root/tsig_key.txt
echo ${TSIG_KEY} > /root/tsig_key.txt
export FACTER_tsig_key=${TSIG_KEY}


#
#If your machines hostname does not resolve to its public IP address, do the following:
#

#Add an entry in /etc/hosts mapping the machines hostname to its public IP. Eg:
#127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
#::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
#10.211.55.3 thishost.thisdomain.com
#Update the /etc/hostname file. Eg:
#echo "thishost.thisdomain.com" > /etc/hostname
#hostname thishost.thisdomain.com

PUBLIC_HOSTNAME=$(  facter ec2_public_hostname )
PUBLIC_IP=$( facter ec2_public_ipv4 )
PRIVATE_HOSTNAME=$( facter ec2_local_hostname )
PRIVATE_IP=$( facter ec2_local_ipv4 )

echo ${PUBLIC_HOSTNAME} > /etc/hostname
hostname ${PUBLIC_HOSTNAME}
echo ${PUBLIC_IP} ${PUBLIC_HOSTNAME} >> /etc/hosts
echo ${PRIVATE_IP} ${PRIVATE_HOSTNAME} >> /etc/hosts

#
# Remove Puppetlabs repos and certain packages ... interferes with OpenShift
#
yum -y remove mcollective mcollective-client mcollective-common 
perl -i -p -e 's/enabled=1/enabled=0/g' /etc/yum.repos.d/puppet*.repo

#
# Enable SELinux into permissive mode ..
#

#                                                                                                                                                                                         
# pull & setup the puppet modules and run manifest
cd /tmp
git_pull ${PUPPET_REPO_URL} ${PUPPET_REPO_BRANCH}
do_puppet ./manifests/site.pp
