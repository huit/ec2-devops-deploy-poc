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

prepare_rhel6_for_puppet "${EXTRA_PKGS}"

# Allow the instance to access S3 bucket with appropriate data
setup_aws_creds

#
# pull, setup and run puppet manifests
#
cd /tmp 
git_pull ${PUPPET_REPO_URL} ${PUPPET_REPO_BRANCH}
puppet apply ./manifests/site.pp --modulepath=./modules


#
# Bail OUT
#
exit 0


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

# Setup the files directory
mkdir -p /var/www/drupal/sites/default/files || /bin/true
chmod 777 /var/www/drupal/sites/default/files -R

#-------------------------------------
# Application customizations next,
#  or a default vanilla install
#  if not specified ..
#
# Assume everything is in S3 or Git
#--------------------------------------

# Setup the AWS credentials again, since they are 
#  temporary
setup_aws_creds

#
# Create a temporary directory to pull any  
#   app data or custom code
#

tmpd=$( mktemp -d )
cd ${tmpd}

#----
# Pull from provided URLs any private data 
#  for the application
#----
pull_private_data $DATA_URLS

#----
# If specified, pull in custom Drupal code/profiles/modules
#----

# If we were provided a git repo, pull and copy over the content.
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

#----
# Install & enable any modules
#----

#
# Add any requested drupal modules 
#  that are generally available
# 
MODS="${DRUPAL_MODULES}"
cd /var/www/drupal
for mod in ${MODS}; do
	drush dl ${mod} -y && drush en ${mod} -y	
done
cd ${tmpd}	

# Custom modules copied over ...
#
# Fix up modules ... seems that custom modules aren't picked up
#  by an install?

if [ -d /var/www/drupal/sites/all/custom ]; then
	
	cd /var/www/drupal/sites/all/modules
	mods=$( ls ../custom )
	for mod in $mods; do 
		ln -s ../custom/${mod} .
	done
	cd /var/www/drupal
	for mod in $mods; do 
		drush en ${mod} -y
	done				
	cd ${tmpd}
	
fi


#----
# Do a site install: custom or vanilla
#----

#
# Install the profile if provided
#
DRUPAL_PROFILE_NAME=${DRUPAL_PROFILE_NAME:-standard}
DRUPAL_SITE_NAME=${DRUPAL_PROFILE_NAME:-Standard Drupal Dev Site}
DRUSH_OPTIONS=" -y \
  --db-url=mysql://drupal:drupal@localhost/drupal \
  --account-name=admin \
  --account-pass=admin \
  --db-su=root \
  --db-su-pw=password \
  --site-name=\"${DRUPAL_SITE_NAME}\""
DRUSH_CMD="drush si ${DRUPAL_PROFILE_NAME}"

cd /var/www/drupal
echo "Doing a Drupal site-install: \"$DRUSH_CMD $DRUSH_OPTIONS\""
$DRUSH_CMD $DRUSH_OPTIONS
cd ${tmpd}

	
# include any user data (assume top level dir is "files/"
if ! [ -z "${SITE_DATA}" ]; then 

	cd /var/www/drupal/sites/default
	tar xzvf ${tmpd}/${SITE_DATA} >/dev/null 2>&1
	chmod -R 777 .
	cd ${tmpd}

fi

#
# If provided, replace the database with current version
#
if ! [ -z "${SITE_DATABASE_FILE}" ]; then 
	
	cat "${SITE_DATABASE_FILE}" | gunzip - | mysql -u root -ppassword drupal 

fi


#--------------------------------------------
#
#  Test APPLICATION
#
#--------------------------------------------

