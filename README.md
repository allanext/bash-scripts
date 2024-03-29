A few Bash scripts that might eventually be helpful to somebody !

## [aws_replicate_ec2.sh](https://github.com/allanext/bash-scripts/blob/master/aws_replicate_ec2.sh)

 Quick and dirty example on how to clone of a EC2 instance for test purposes.
 There are better ways to test OS changes in production environments, 
 the truth though is that you don't always have a perfect infrastructure!
 This script replicates an EC2 AWS instance using the AWS cli.

 Usage:
   ./aws_replicate_ec2.sh [instance id]
 Requirements:
   - aws cli (brew install aws-cli@2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-install)
   - jq (brew install jq | yum install jq) 
   - create aws cli profiles (aws configure --profile SRC_PROFILE; aws configure --profile test) 
   - in the EC2 instance you'll have to set an ~/.ssh/config entry in order to access the test server. 
     You could allocate an elastic IP just for test instances. Example of ~/.ssh/config :
       host server_name-test
       User ec2-user           
       HostName XX.WW.YY.ZZ
       StrictHostKeyChecking no
       IdentityFile ~/.ssh/AWS/server_key.pem
   - script configuration below

 The following are the steps of the script:
   - Deregister old AMI with TEST tag
   - Create new AMI from instance chosen
   - Initialize new AMI
   - Wait for AMI ready
   - Grant AMI permission to destination account
   - Launch test instance
   - Settings tags
   - Elasic IP association
   - Waiting for OS and ssh to load
   - Change httpd configuration in /etc/httpd/sites-available/*
   - Change Mediawiki configuration
   - Change Wordpress configuration
   - Launch daemons
   - Create script to terminate ec2 replica instance

   MISSING:
   - Add basic authentication to test sites

## [islandora-batch-import-setup.sh](https://github.com/allanext/bash-scripts/blob/master/islandora-batch-import-setup.sh)

Simple script for preparing the folder structure necessary to feed the islandora batch import module (https://github.com/Islandora/islandora_book_batch). It expects a folder of tif files that are in sequence like pages of a book (e.g MYBOOK_001.tif, .. ,MYBOOK_345.tif) and it will output the structure as required by the module.
