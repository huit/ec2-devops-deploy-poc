#!/bin/bash

#
# Simple demo boostrap script to be run by cloud-init, that
#  shows that the script executed by writing a root web page.
#

#
# Normally this would use a boilerplate setup to enable puppet, etc.
#  such as:
# """
# prepare_rhel6_for_puppet ${EXTRA_PKGS}
# setup_aws_creds
# """
#
# but here we'll just do it directly ...


# install & start apache and setup a target web root dir for apache
yum -y install httpd emacs-nox
/sbin/service httpd start 
mkdir -p /var/www/html

contents=$( cat $0 | sed 's/\&/\&amp;/g'  | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g' )
cat <<EOF > /var/www/html/index.html
<html>
 <head><title>Successful Bootstrapping</title></head>
 <body>
<h1> Successully Bootstrapped</h1>

<div style="background-color:#DDDDDD; border:1px; margin:40px;"> 
	<pre>$contents</pre>
 </div>
</body>
</html>

EOF