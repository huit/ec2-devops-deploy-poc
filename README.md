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


- [Markdown Syntax (for this doc)](http://daringfireball.net/projects/markdown/syntax)
- [DevOps in the Cloud eBook/resources](http://www.devopscloud.com/)
- [cloud-init docs](https://cloudinit.readthedocs.org)
- [Amazon EC2 command line tools](http://aws.amazon.com/developertools/351)


QuickStart
----------

This work will be run initially as a shell script from the command line on your client
machine, using the EC2 command line tools. Ultimately, we'll document how to initiate
the start and build of the client system from other mechanisms, including from a CI build
system.

