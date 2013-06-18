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


# These are pretty much defaults from various puppet modules.
DB_NAME=drupal
DB_USERNAME=drupal
DB_PWD=drupal
DB_ROOT_USERNAME=root
DB_ROOT_PWD=password
DB_HOST=localhost
DB_URL=mysql://${DB_USERNAME}:${DB_PWD}@${DB_HOST}/${DB_NAME}

DRUPAL_ROOT=/var/www/drupal/


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

#*********************************
# Define a set of functions to do 
#  various aspects of building a 
#  Drupal site
#******************************

setup_drush() {
	
	# FIXME: Add in DRUSH using "pear" until puppet modules are better
	pear channel-discover pear.drush.org
	pear install drush/drush
}

get_custom_data() {
	
	# Setup the AWS credentials again, since they are 
	#  temporary
	#setup_aws_creds

	local tmpd=$( mktemp -d )
	cd ${tmpd}

	#
	# Pull from provided URLs any private data 
	#  for the application
	#
	pull_private_data $DATA_URLS
		
	echo $tmpd				
}

#
# Installs a generic Drupal instance
# 
install_drupal() {
	
	#
	# Pull and install Drupal 
	#
	local orig_dir=$( pwd )
	mkdir -p ${DRUPAL_ROOT}
	cd ${DRUPAL_ROOT}/; cd ..
	rm -rf drupal*
	
	git_pull ${1} ${2}
	ln -sf $(pwd) ../drupal 

	# Setup the files directory
	mkdir -p  ${DRUPAL_ROOT}/sites/default/files
	chmod 777 ${DRUPAL_ROOT}/sites/default/files -R
	cd ${orig_dir}
}

install_drupal_modules() {
	
	#
	# Add requested drupal modules
	# 
	local orig_dir=$( pwd )
	cd ${DRUPAL_ROOT}
	MODS="${1}"
	for mod in ${MODS}; do
		drush dl ${mod} -y 
		drush en ${mod} -y	
	done
	cd ${orig_dir}
}

install_standard_drupal_site() {
	
	# Do a default, standard installation 
	local orig_dir=$( pwd )
	cd ${DRUPAL_ROOT}
	drush si standard \
	 --db-url=${DB_URL} \
	 --db-su=${DB_ROOT_USERNAME} \
	 --db-su-pw=${DB_ROOT_PWD}\
	 --site-name="Drupal Vanilla Dev Site" \
	 -y
	cd ${orig_dir}
}
	
install_custom_drupal_code() {
	
	local orig_dir=$( pwd )
	
	# Capture original sites/ 
	cd ${DRUPAL_ROOT}
	cp -av sites sites.orig	
	cp sites/default/settings.php ${orig_dir}/
	
	# 
	# pull a repo of the application code 
	if ! [ -z "${APP_REPO_URL}" ]; then 
		git_pull ${APP_REPO_URL} ${APP_REPO_BRANCH}
		cp -rf sites profiles ${DRUPAL_ROOT}/
	fi

	# unpack an archive of the application code that was already downloaded
	if ! [ -z "${APP_ARCHIVE_FILE}" ]; then 	
		cd ${DRUPAL_ROOT}
		tar xzf ${tmpd}/${APP_ARCHIVE_FILE}
		cd -
	fi

	# move any old settings.php files out of the way
	mv -f ${DRUPAL_ROOT}/sites/default/settings.php ${DRUPAL_ROOT}/sites/default/settings.php.old
	
	# Fix up modules ... seems that custom modules are in
	#   the wrong place?
	if [ -d ${DRUPAL_ROOT}/sites/all/custom ]; then
		
		cp -av ${DRUPAL_ROOT}/sites/all/custom/* \
			${DRUPAL_ROOT}/profiles/${DRUPAL_PROFILE_NAME}/modules/custom/
	fi
	
	chown -R root:root ${DRUPAL_ROOT}
	
	cd ${orig_dir}
}		

#
# Sets up an empty data, loads data if neeeded
#  and clears out any caches
#
setup_site_database() {
	
	local orig_dir=$( pwd )
		
	# this should blow away original database
	drush sql-create -y \
        --db-url=${DB_URL} \
        --db-su=${DB_ROOT_USER} \
        --db-su-pw=${DB_ROOT_PWD}
    
    # Database pukes on occasion .. this seems to help.
	# Also see ...http://dev.mysql.com/doc/refman/5.0/en/gone-away.html
	# and look into setting 'max_allowed_packet' variable.

    service mysqld restart
    
	if ! [ -z "${SITE_DATABASE_FILE}" ]; then 
		cat "${SITE_DATABASE_FILE}" | \
		gunzip - | \
		mysql -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PWD} ${DB_NAME} 
	
		# clear out any cache tables
		cd /var/www/drupal
		drush cache-clear all
		
		#CACHES=$( echo "show tables;" | mysql drupal -ppassword | grep cache )
		#for CACHE in $CACHES; do
			#	echo "delete from ${CACHE};" | mysql -u ${DB_ROOT_USERNAME} -p${DB_ROOT_PWD} ${DB_NAME} 
		#done
	fi
	cd ${orig_dir}	
}

install_site_data() {
	
	local orig_dir=$( pwd )
		
	# include user data (assume top level dir is "files/"
	if ! [ -z "${SITE_DATA}" ]; then 

		cd ${DRUPAL_ROOT}/sites/default
		tar xzf ${tmpd}/${SITE_DATA} 2>/dev/null
		cd -
	fi
	
	chmod -R 777 ${DRUPAL_ROOT}/sites/default/files
	cd ${orig_dir}		
}	

configure_settings_php() {
	cp ./settings.php ${DRUPAL_ROOT}/sites/default/
}

configure_varnish_caching() {

	cd /var/www/drupal
	drush vset cache 1 
	
	cat >> ${DRUPAL_ROOT}/sites/default/settings.php <<"EOF"

# Enable caching and use varnish
$conf['reverse_proxy'] = TRUE;
$conf['reverse_proxy_addresses'] = array('127.0.0.1');
$conf['caching'] = '1';
EOF

}

#
# Configure settings.php with proper connection string.
#


#************
#
# MAIN
#
#************

setup_drush
echo "Using drush version from: $( which drush )"

echo "Pulling private website code, files and database ..."
tmpd=$( get_custom_data )
cd ${tmpd}

echo "Installing upstream Drupal code ..."
install_drupal ${DRUPAL_REPO_URL} ${DRUPAL_REPO_BRANCH}

echo "Creating a vanilla Drupal site ..."
install_standard_drupal_site

echo "Installing desired extra modules ... "
install_drupal_modules "${DRUPAL_MODULES}"

# Check for customizations ...
if ! [ -z "${APP_REPO_URL}" -a -z "${APP_ARCHIVE_FILE}" ]; then

	echo "Installing any custom Drupal Code ..."
	install_custom_drupal_code

	echo "Setting up site database from SQL dump ...."
	setup_site_database

	echo "Copying site files ... "
	install_site_data

	echo "Setup settings.php for this site ..."
	configure_settings_php
fi

# setting up varnish caching ...
configure_varnish_caching

# install varnish drush module, so that we can purge the cache, etc.
install_drupal_modules "varnish"

# Fix up the database as needed, and clear the cache
cd /var/www/drupal && drush updatedb -y
cd /var/www/drupal && drush cache-clear all

service httpd restart 
service varnish restart 







