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
# pull & setup the puppet modules and run manifest
cd /tmp
git_pull ${PUPPET_REPO_URL} ${PUPPET_REPO_BRANCH}
do_puppet ./manifests/site.pp
