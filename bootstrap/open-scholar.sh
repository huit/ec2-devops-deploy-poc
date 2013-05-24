#!/bin/bash
# 
# This bootstrap script uses puppet to setup a
#  LAMP platform appropriate for Drupal + OpenScholar
#
# assumes the following bash vars are defined:
#
#  - PUPPET_REPO_URL
#  - PUPPET_REPO_BRANCH
#
#  - DRUPAL_REPO_URL
#  - DRUPAL_REPO_BRANCH
#
#  - OPENSCHOLAR_REPO_URL
#  - OPENSCHOLAR_REPO_BRANCH
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
# pull, setup and run puppet manifests
#
cd /tmp 
git_pull ${PUPPET_REPO_URL} ${PUPPET_REPO_BRANCH}
puppet apply ./manifests/site.pp --modulepath=./modules

#--------------------------------------------
#  Build and configure APPLICATION
#--------------------------------------------

#
# Drupal framework first
#
# NOTE: let's for now just use the mechanism in OPenScholar to
#  setup Drupal, and comment this out.

#cd /var/www
#git_pull ${DRUPAL_REPO_URL} ${DRUPAL_REPO_BRANCH}
#ln -sf $(pwd) ../drupal

# Vanilla install
#drush si standard \
# --db-url=mysql://drupal:drupal@localhost/drupal \
# --db-su=root \
# --db-su-pw=password \
# --site-name="Drupal Dev Site" \
# -y

# Add any Drupal modules desired ...
#drush dl blazemeter -y && drush en blazemeter -y
#chmod 777 /var/www/drupal/sites/default/files -R

#
# App next: pull openscholar
#
cd /var/www/
git_pull ${OPENSCHOLAR_REPO_URL} ${OPENSCHOLAR_REPO_BRANCH}
mv $(pwd) $(pwd)-build

# Build it out ...
BUILD_ROOT=$(pwd)-build
OPENSCHOLAR_ROOT=/var/www/openscholar
DRUPAL_ROOT=/var/www/drupal

DRUSH=drush

#------------- BEGIN: from scripts/build ------------------

echo "Begin to build and install OpenScholar from ${BUILD_ROOT} to ${OPENSCHOLAR_ROOT}"

# Chores.
(
  for DIR in $BUILD_ROOT/www-build sites-backup openscholar/1 openscholar/modules/contrib openscholar/themes/contrib openscholar/libraries; do
    rm -Rf $DIR
  done
)

# Build the profile itself.
(
  cd openscholar
  $DRUSH make --no-core --contrib-destination drupal-org.make .
  cd ..
)

# Build core and move the profile in place.
(
  # Build core.
  $DRUSH make openscholar/drupal-org-core.make $BUILD_ROOT/www-build

  # Check if sites/default exists, which means it is an existing installation.
  SITES_DEFAULT=${OPENSCHOLAR_ROOT}/sites/default
  if [ -d ${SITES_DEFAULT} ]; then
    cp -rp ${SITES_DEFAULT}  sites-backup
  fi

  # Restore the sites directory.
  if [ -d sites-backup ]; then
    rm -Rf $BUILD_ROOT/www-build/sites/default
    mv sites-backup/ $BUILD_ROOT/www-build/sites/default
  fi

  # Copy the profile in place.
  cp -a openscholar  $BUILD_ROOT/www-build/profiles/

  # Fix permisions before deleting.
  chmod -R +w ${OPENSCHOLAR_ROOT}/sites/* || true
  rm -Rf ${OPENSCHOLAR_ROOT} || true

  # Restore updated site. 
 echo mv $BUILD_ROOT/www-build ${OPENSCHOLAR_ROOT}
  mv $BUILD_ROOT/www-build ${OPENSCHOLAR_ROOT}
)

# Copy unmakable contrib files
(
  mkdir -p ${OPENSCHOLAR_ROOT}/modules/contrib/
  cp -R temporary/* ${OPENSCHOLAR_ROOT}/modules/contrib/
)

echo "End of OpenScholar installation to  ${OPENSCHOLAR_ROOT}"

#------------- END: from scripts/build ------------------

cd ${OPENSCHOLAR_ROOT}

# Add in needed modules (is this needed?)
MODS=" ctools context cfeatures boxes views strongarm date date_ical entity token "
MODS="${MODS} pathauto advanced_help imagefield_crop jcarousel oembed file_entity "
MODS="${MODS} wysiwyg wysiwyg_filter media_oembed entitycache views_litepager "
MODS="${MODS} restws views_slideshow_cycle diff twitter_pull nice_menus"
MODS="${MODS}  shorten respondjs views_infinite_scroll "

for mod in ${MODS}; do
	drush dl ${mod} -y && drush en ${mod} -y	
done

#chmod 777 /var/www/drupal/sites/default/files -R

# Do a site install

drush si -y openscholar \
	--account-pass=admin \
	--db-url=mysql://drupal:drupal@localhost/os \
	--db-su=root \
	--db-su-pw=password \
	--uri=http://localhost/os \
	--site-name="OpenScholar Dev Site" \
	openscholar_flavor_form.os_profile_flavor=development \
	openscholar_install_type.os_profile_type=vsite

drush vset purl_base_domain ''
drush en -y os_migrate_demo
drush mi --all --user=1

ln -s ${OPENSCHOLAR_ROOT} ${DRUPAL_ROOT}

# For the impatient
service httpd   restart 
service varnish restart 


#--------------------------------------------
#
#  Test APPLICATION
#
#--------------------------------------------

