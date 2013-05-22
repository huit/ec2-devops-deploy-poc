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
# pull & setup puppet modules and manifest
cd /tmp
git_pull ${PUPPET_REPO_URL} ${PUPPET_REPO_BRANCH}
mkdir modules && ln -s $(pwd) modules/jenkins
git submodule add git://github.com/puppetlabs/puppetlabs-stdlib.git modules/stdlib
git submodule add git://github.com/puppetlabs/puppetlabs-apache.git modules/apache

cat <<EOF >  manifests/site.pp
include jenkins
#jenkins::plugin {'swarm':}

EOF

mkdir -p /etc/httpd/conf.d
cat <<EOF > /etc/httpd/conf.d/jenkins.conf
ProxyPass         /  http://localhost:8080/
ProxyPassReverse  /  http://localhost:8080/
ProxyRequests     Off

<Proxy http://localhost:8080/*>
  Order deny,allow
  Allow from all
</Proxy>
EOF

yum -y install httpd mod_ssl

puppet apply ./manifests/site.pp --modulepath=./modules


