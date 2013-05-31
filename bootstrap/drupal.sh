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

# Allow the instance to access S3 bucket with appropriate data
setup_aws_creds

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
# Pull and install Drupal first
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

# Do a default, standard installation 

drush si standard \
 --db-url=mysql://drupal:drupal@localhost/drupal \
 --db-su=root \
 --db-su-pw=password \
 --site-name="Drupal Vanilla Dev Site" \
 -y

#
# Application customizations next
#
# Assume everything is in S3 or Git
#

# Setup the AWS credentials again, since they are 
#  temporary
setup_aws_creds

tmpd=$( mktemp -d )
cd ${tmpd}

#
# Pull from provided URLs any private data 
#  for the application
#
pull_private_data $DATA_URLS

# replace the database with current version
if ! [ -z "${APP_REPO_URL}" ]; then 
	git_pull ${APP_REPO_URL} ${APP_REPO_BRANCH}
	cp -rf sites profiles /var/www/drupal/
fi

# unpack an archive of the application code that was already downloaded
if ! [ -z "${APP_ARCHIVE_FILE}" ]; then 
	
	cd /var/www/drupal
	tar xzvf ${tmpd}/${APP_ARCHIVE_FILE}
	cd ${tmpd}	

fi

# Fix up modules ...

cd /var/www/drupal/sites/all/modules
ln -s ../custom/* .
cd ${tmpd}

#
# Install the profile if provided
#
if ! [ -z "${DRUPAL_PROFILE_NAME}" ]; then

	cd /var/www/drupal
	drush si ${DRUPAL_PROFILE_NAME} \
	 --db-url=mysql://drupal:drupal@localhost/drupal \
	 --db-su=root \
	 --db-su-pw=password \
	 --site-name="${DRUPAL_PROFILE_NAME}" \
	 -y
	cd ${tmpd}		
fi

#
# replace the database with current version
#
if ! [ -z "${SITE_DATABASE_FILE}" ]; then 
	
	cat "${SITE_DATABASE_FILE}" | gunzip - | mysql -u root -ppassword drupal 

fi


# include user data (assume top level dir is "files/"
if ! [ -z "${SITE_DATA}" ]; then 

	cd /var/www/drupal/sites/default
	tar xzvf ${tmpd}/files.tgz
	cd ${tmpd}

fi

#--------------------------------------------
#
#  Test APPLICATION
#
#--------------------------------------------

