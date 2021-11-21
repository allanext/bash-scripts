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
   - Cleanup of AMIs

## [docker-compose.yml](https://github.com/allanext/bash-scripts/blob/master/docker-compose.yml) that fires a MediaWiki container with MariaDB, Redis and Elastic search

 In front of the Wiki you can use nginx reverse proxy + let's encrypt: 
 https://github.com/evertramos/nginx-proxy-automation

 The following Dockerfile adds the Redis php extension to the mediawiki image:
 
 FROM mediawiki:1.35
 RUN apt-get update && pecl install -o -f redis \
 &&  rm -rf /tmp/pear \
 &&  docker-php-ext-enable redis
 
 To install elasticsearch follow these guides:
 https://www.mediawiki.org/wiki/Extension:CirrusSearch#Configuration
 https://gerrit.wikimedia.org/g/mediawiki/extensions/CirrusSearch/%2B/HEAD/README
 The host needs to set something like:
 sudo sysctl -w vm.max_map_count=262144
