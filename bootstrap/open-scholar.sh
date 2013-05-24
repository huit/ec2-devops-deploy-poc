#!/bin/bash
# 
# This bootstrap script uses puppet to setup a
#  LAMP platform appropriate for Drupal
#
# assumes the following bash vars are defined:
#
#  - PUPPET_REPO_URL
#  - PUPPET_REPO_BRANCH
#
#  - DRUPAL_REPO_URL
#  - DRUPAL_REPO_BRANCH
#  - APP_REPO_URL=
#  - APP_REPO_BRANCH
#
#  - EXTRA_PKGS (optional)

#---------------------------------
#  Build and configure PLATFORM
#---------------------------------

prepare_rhel6_for_puppet ${EXTRA_PKGS}


#
# pull, setup and run puppet manifests
#
cd /tmp 
git_pull ${PUPPET_REPO_URL} ${PUPPET_REPO_BRANCH}
puppet apply ./manifests/site.pp --modulepath=./modules

#--------------------------------------------
#  Build and configure APPLICATION
#--------------------------------------------

#
# Drupal first
#
cd /var/www
git_pull ${DRUPAL_REPO_URL} ${DRUPAL_REPO_BRANCH}
ln -sf $(pwd) ../drupal

which drush

drush si standard \
 --db-url=mysql://drupal:drupal@localhost/drupal \
 --db-su=root \
 --db-su-pw=password \
 --site-name="Drupal Dev Site" \
 -y

drush dl blazemeter -y && drush en blazemeter -y
chmod 777 /var/www/drupal/sites/default/files -R


#
# App next
#


#--------------------------------------------
#
#  Test APPLICATION
#
#--------------------------------------------

