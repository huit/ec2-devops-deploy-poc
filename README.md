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

Install the EC2 command line utlities, which require a valid Java installation. Also a basic Linux/UNIX 
command environment, including BASH, awk, grep, etc. Lastly, you'll need Git in order to 
clone this repository.

QuickStart
----------

This work will be run initially as a shell script from the command line on your client
machine, using the EC2 command line tools. Ultimately, we'll document how to initiate
the start and build of the client system from other mechanisms, including from a CI build
system.

To start, clone this repository (see the top of the page) then edit the _localrc_ file
to reflect your specific information, and to choose a bootstrap script to provide 
to cloud-init on the newly launched instance. In particular, change all the "EC2_*"
variables to point to your own account resources, and feel free to turn off debugging (set to "n").

    $ git clone [this repository]
    $ cd ec2-drupal-devops-deploy-poc
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

More Advanced Cases
-------------------

To do something more advanced, you need to add more data/configs to control how the system is imaged,
and to install and configure the application. Here we'll examine a drupal installation.

To do this, we need to find or build a few set of data:

1. A config file (here a "localrc") file that specified attributes of the build desired, 
including code repos and branches (this includes puppet code)

2. A basic driver script that performs the operations on the fresh instance

3. A set of puppet modules and site file that will setup the system

4. Any platform/framework code needed for the application

5. The application code itself.

For applications that use a runtime environment or framework such as Tomcat, Drupal, or Ruby on Rails, 
these environments can be part of the operating environment (3) or the platform (4), depending
on how tightly coupled the framework is to the application.

As for the sets of data, the first two are simple scripts on the client. The rest are easily stored
are git repos and cloned by the driver script at the appropriate time.

For drupal, the config file specified the following

- Details  of the instance type and attributes to deploy;
- The driver script to use, and any extra settings for that;
- The puppet repo to use to configure the system; and 
- The application -- and optionally the framework -- to deploy, all from source.




In our case







