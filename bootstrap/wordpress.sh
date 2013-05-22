#!/bin/bash
# 
# This bootstrap script uses puppet to setup a
#  LAMP platform appropriate for WordPress
#
# assumes the following bash vars are defined:
#
#  - PUPPET_REPO_URL
#  - PUPPET_REPO_BRANCH
#
#  - WORDPRESS_REPO_URL
#  - WORDPRESS_REPO_BRANCH
#
#  - APP_REPO_URL=
#  - APP_REPO_BRANCH
#
#  - EXTRA_PKGS (optional)

#---------------------------------
#  Build and configure PLATFORM
#---------------------------------

prepare_rhel6_for_puppet ${EXTRA_PKGS}


#
# Pull Wordpress
#
cd /tmp
git_pull ${WORDPRESS_REPO_URL} ${WORDPRESS_REPO_BRANCH}
ln -sf $(pwd) ../wordpress

#
# pull & setup puppet modules and manifest
#
cd /tmp 
git_pull ${PUPPET_REPO_URL} ${PUPPET_REPO_BRANCH}
mkdir modules && ln -s $(pwd) modules/wordpress 

#
# Run puppet to install Wordpress
#
puppet apply ./manifests/site.pp --modulepath=./modules

#
# Setup wordpress
#


