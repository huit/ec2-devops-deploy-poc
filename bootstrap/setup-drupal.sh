#!/bin/bash
# 
# This bootstrap script uses puppet to setup a
#  LAMP platform appropriate for Drupal
#

#PUPPET_REPO=https://github.com/robparrott/puppet-drupal.git 
PUPPET_REPO=https://github.com/robparrott/puppet-drupal-lamp.git
DRUPAL_REPO=https://github.com/robparrott/drupal-poc.git
APP_REPO=

#
# Install basics to bootstrap this process
#
PKGS="puppet git emacs-nox"
yum -y install ${PKGS}
cp /etc/system-release /etc/redhat-release # to convince puppet we're a RHEL derivative

#
# pull, setup and run puppet manifests
#
cd /tmp 
git clone ${PUPPET_REPO}
PUPPET_DIR=$( echo ${PUPPET_REPO} | awk -F/ '{print $NF}' | sed 's/\.git//' )
cd $PUPPET_DIR
git submodule sync 
git submodule update --init  

puppet apply ./manifests/site.pp --modulepath=./modules

#
# Now pull Drupal and set it up.
#
git clone ${DRUPAL_REPO} /var/www/html/







#
# Some scripting that installs a specific Drupal App for testing purposes.
#
#ssh root@$IP 'wget -O - http://download.newrelic.com/548C16BF.gpg | apt-key add -'
#ssh root@$IP 'echo "deb http://apt.newrelic.com/debian/ newrelic non-free" > /etc/apt/sources.list.d/newrelic.list'

#ssh root@$IP 'apt-get update -y'
#ssh root@$IP 'apt-get install newrelic-php5 newrelic-sysmond -y'
#ssh root@$IP 'cp /etc/newrelic/newrelic.cfg.template /etc/newrelic/newrelic.cfg'

#ssh root@$IP 'rm -rf /var/www/'
#ssh root@$IP 'cd /tmp; wget http://ftp.drupal.org/files/projects/commerce_kickstart-7.x-2.4-core.tar.gz; tar -xvf commerce_kickstart-7.x-2.4-core.tar.gz; mv commerce_kickstart-7.x-2.4 /var/www;'
#ssh root@$IP 'cd /var/www; drush site-install commerce_kickstart --db-url=mysql://drupal:ChangeMelikeRIGHTNOW@localhost/drupal --site-name=DrupalCampLondon2013 -y'
#ssh root@$IP 'cd /var/www; drush dl blazemeter -y; drush en blazemeter -y;'
#ssh root@$IP 'chmod 777 /var/www/sites/default/files -R'
