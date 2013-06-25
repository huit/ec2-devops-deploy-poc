Overview
--------

This is an example/exploratory repo for showing how to automate the deployment of a webapp
(in this case Drupal) on an Amazon EC2 instance. The ultimate goal will be to make this
process reproducible across a variety of application platforms and arhitectures, and
to incorporate the use of Amazon CloudFormation where needed, as well as setup up a
continuous integration capability using Jenkins & GitHub. Currently this approach will 
make good use of GitHub to host applicaiton code, puppet scripts, and deployment scripting.

Links
-----

Use links related to this work:

- [DevOps in the Cloud eBook/resources](http://www.devopscloud.com/)
- [cloud-init docs](https://cloudinit.readthedocs.org)
- [Amazon EC2 command line tools](http://aws.amazon.com/developertools/351)
- [Amazon Linux](http://aws.amazon.com/amazon-linux-ami/)
- [Automate EC2 Instance Setup with user-data Scripts](http://alestic.com/2009/06/ec2-user-data-scripts)
- [Markdown Syntax (for this doc)](http://daringfireball.net/projects/markdown/syntax)

Related GitHub repositories

- https://github.com/robparrott/puppet-drupal
- https://github.com/robparrott/drupal-puppet-modules
- https://github.com/robparrott/drupal-poc
- https://github.com/robparrott/puppet-wordpress

Big Picture
-----------

The big picture here is to use bootstrapping and modern devops appraoches to create a clear and
usable separation-of-concern between Infrastructure, Platform (OS and configs) and Application layers
in the build of the system, and to create a foundation for orchestration and continuous integration.

![Architectural, data, and workflow mashup](../../raw/master/docs/DevOps%20on%20EC2%20Arch.png "Architectural, data, and workflow mashup")

The primary aspect to absorb in this figure is that as you move from left -- where a developer or system 
starts the process of deploying an instance of an application -- to the far right where the application is 
tested or used, the process moves from infrastructure to platform to application. By placing the appropriate
data in separate stores, the data is separated by these levels, and managed by different teams.

The mechanism that allows this is the use of the the user-data field and the "cloud-init" service that consumes 
this data. The hook mechanism is to name a target repository and optionally a tag or branch in the 
original deployment creation process; these values are passed down the line until it's time to modify the
system to meet the state specified in these data sources.

The implementation here is pretty ghetto, but aimed to be portable, since it's written copmletely in BASH. 
It provides an basic framework for  deploying & building single system images. More advanced work should
use CloudFormation and a more capable framework.
	
Assumptions
-----------

Quick dump of  assumptions/axioms as we approach this.

- Try wherever possible to use standards and rely on the work of others (who probably know more than we do!)
- Everything that is modified from a base standard must go into version control.
- Be as open as possible. We're not building the next great software company, and we're not storing confidential 
  data, so be open.
- If we are trying to store or use confidential data in a Devel/TestBed setup, we should stop, reevaluate certain 
  life choices, and consider a career in retail sales or manipulative crafts.
- Make every step reproducible and automated.  If we are hand crafting systems, then ... well, see above.
  
Given these assumptions, more concretely let's do this:

- Use EC2-supplied base AMIs: let others secure and manage our images for us (particularly in DevTest).
-- See http://ec2-downloads.s3.amazonaws.com/AmazonLinuxAMIUserGuide.pdf
-- This thing is based on CentOS plus some security and functionality patches
-- It's binary compatible with CentOS 6/RHEL 6.
- All modifications to image take place after boot.
- Bootstrap all customization using "cloud-init," which uses the Amazon EC2 metadata service to run automated scripts on boot.
- Use puppet to produce a reproducible system and platform environment on the remote instance.
- Use GitHub to store all code-like data publicly.
- Use Amazon S3 to store any BLOB-like data, and any private data, such as 
-- Database dumps
-- significantly sized media files
-- any keys or passwords.

Requirements
------------

The basic requirement is a UNIX/Linux (Mac OS X is UNIX underneath) command line and various client tools. In particular:

- A basic Linux/UNIX command environment, including BASH, awk, grep, etc.
- Install the EC2 command line utilities 
- Java installation (for above)
- Install the [s3cmd client tools](http://s3tools.org/s3cmd).
- uuidgen command line tool to create uuids
- Git command line

On the Mac, most of this can be installed using [HomeBrew](http://mxcl.github.io/homebrew/).

In addition, you'll need to setup EC2 to 

QuickStart
----------

This work will be run initially as a shell script from the command line on your client
machine, using the EC2 command line tools. Ultimately, we'll document how to initiate
the start and build of the client system from other mechanisms, including from a CI build
system.

To start, we need to setup some things in EC2 so that we can access the site and the host. From the
EC2 web console at 

    http://console.aws.amazon.com/
    
connect the the console for EC2. From here, create an SSH keypair, and download the keypair 
to your laptop into a secure directory (i.e. `~/.ssh/`). Then on a Linux or Mac platform, 
fix the permssions on this key, and load it into an SSH agent by running the 
command

    $ chmod ~/.ssh/mykey.pem
    $ ssh-add ~/.ssh/mykey.pem
    
Once loaded, you are ready to login to the host. You'll need to reload the key into the 
ssh-agent every time you logout and back in.

Next you'll need to create a "security-group" -- or set of EC2 firewall rules -- for accessing the
website and host when it's running. Make sure to open ports 22 for SSH and 80 & 443 for web access.
For a dev/test environment that doesn't contain sensitive data and is temporary, you can open
this to the internet; otherwise restrict access to Harvard subnets.

Note both the name of the security group and the keyapir you created for later.

Next, clone this repository (see the top of the page) then edit the _localrc_ file
to reflect your specific information (i.e. keypair and security group, instance size, etc.), 
and to choose a bootstrap script to provide to cloud-init on the newly launched instance. 
In particular, change all the "EC2_*" variables to point to your own account resources, 
and feel free to turn off debugging (set to "n").

    $ git clone [this repository]
    $ cd ec2-devops-deploy-poc
    $ cp examples/localrc.simple-web localrc
    $ vi localrc

Then from the root directory

    $ ./launch.sh
   
This will start up an instance, then push the script specified by the "$BOOTSTRAP" variable   
to the started instance in the "user-data" meta-data field, which will be consumed by the "cloud-init"
service on the instance, and executed at the end of the startup sequence. If this is set to 

    BOOTSTRAP=bootstrap/simple-web.sh

The resulting instance will boot up and then create a very simple static root web page. 
To see it, use the instance id values output bu the launch.sh script, and use the command line 
tool

    $ ec2-describe-instances [instance id]    

Which will print out the various metadata about the system. Find the public URL (with the 
"*compute-1.amazonaws.com domain name) and past it into a browser.

To login to the instance, you can use the helper script:

    $ ./login.sh [instance id]

For debugging/devel purposes, it's convenient to capture the instance id output from the launch.sh script
on the command line, as such:

    $ INSTANCE_ID=$( ./launch.sh )
    ... wait ...
    $ ./login.sh ${INSTANCE_ID}
    ... do some stuff ...
    $ ./web.sh  ${INSTANCE_ID}
    ... look at some stuff in a browser window ...
    $ ec2-terminate_instance ${INSTANCE_ID}



More Advanced Cases
-------------------

To do something more advanced, you need to add more data/configs to control how the system is imaged,
and to install and configure the application. The current options include:

- [Drupal](http://drupal.org)
- [OpenScholar](http://openscholar.harvard.edu/)
- [Wordpress](http://wordpress.org/)
- [MediaWiki](http://mediawiki.org)
- [Ruby on Rails Sample App](http://rubyonrails.org)
- [Jenkins CI Server](http://jenkins-ci.org/)

In addition, some play cases for OpenShift and OpenStack.

Here we'll examine a Drupal installation.

=== Drupal ===

To do this, we need to find or build a few set of data:

1. A config file (here a `localrc`) file that specified attributes of the build desired, 
including code repos and branches (this includes puppet code)

2. A basic driver script that performs the operations on the fresh instance (in our case, likely `bootstrap/drupal.sh`)

3. A set of puppet modules and site file that will setup the system, specified as a puppet repo and associated modules.

4. Any platform/framework code needed for the application

5. The application code itself.

For applications that use a runtime environment or framework such as Tomcat, Drupal, or Ruby on Rails, 
these environments can be part of the operating environment (3) or the platform (4), depending
on how tightly coupled the framework is to the application.

![Areas of concern/responsibility in the devops stack](../../raw/master/docs/Separation-of-concerns-devops-poc.png "Areas of concern/responsibility in the devops stack")


As for the sets of data, the first two are simple scripts on the client. The rest are easily stored
are git repos and cloned by the driver script at the appropriate time.

For drupal, the config file specified the following

- Details  of the instance type and attributes to deploy;
- The driver script to use, and any extra settings for that;
- The puppet repo to use to configure the system; and 
- The application -- and optionally the framework -- to deploy, all from source.

In our case, we can follow 







