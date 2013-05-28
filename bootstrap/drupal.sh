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

# Drush needs php 5.3.5 or later ... CentOS 6.4 only provides 5.3.3
#(
# cd /tmp 
# wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
# rpm -Uvh remi-release-6*.rpm
#)

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

# FIXME: Add in DRUSH using "pear" until puppet modules are better
pear channel-discover pear.drush.org
pear install drush/drush

echo Using drush version from: $( which drush )

#
# Add requested drupal modules
# 
MODS="${DRUPAL_MODULES}"
for mod in ${MODS}; do
	drush dl ${mod} -y && drush en ${mod} -y	
done

# Setup the files directory
chmod 777 /var/www/drupal/sites/default/files -R

# Do the installation (default & standard )

drush si standard \
 --db-url=mysql://drupal:drupal@localhost/drupal \
 --db-su=root \
 --db-su-pw=password \
 --site-name="Drupal Vanilla Dev Site" \
 -y

#
# App next
#

# replace the database with current version
if ! [ -z "${SITE_DATABASE_FILE}" ]; then 
	cd /tmp
	wget ${SITE_DATABASE_FILE} | gzip - | mysql -u root -p password drupal
fi

# include user data
if ! [ -z "${SITE_DATABASE_FILE}" ]; then 
	wget ${SITE_DATA}
fi

#--------------------------------------------
#
#  Test APPLICATION
#
#--------------------------------------------

