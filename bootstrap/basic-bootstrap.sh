#!/bin/bash
# 
# This bootstrap script sets up puppet 
#  and other basics for a more copmlete build out
#
# assumes the following bash vars are defined:
#
#  - EXTRA_PKGS (optional)
#  - DATA_URLS (optional)

#---------------------------------
#  Build and configure PLATFORM
#---------------------------------

prepare_rhel6_for_puppet ${EXTRA_PKGS}

# Allow the instance to access S3 bucket with appropriate data
#setup_aws_creds

#
# Pull from provided URLs any private data 
#  for the application
#
tmpd=$( mktemp -d )
cd ${tmpd}

pull_private_data ${DATA_URLS}

echo "Build of a base platform complete."
