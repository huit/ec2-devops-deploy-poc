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
to cloud-init on the newly launched instance.

    $ git clone [this repository]
    $ cd ec2-drupal-devops-deploy-poc
    $ vi localrc

Then from the root directory

   $ ./launch.sh
   
This will start up an instance, then push the script specified by the "$BOOTSTRAP" variable   
to the started instance in the "user-data" meta-data field, which will be consumed by the "cloud-init"
service on the instance, and executed at the end of the startup sequence. If this is set to 

    BOOTSTRAP=

