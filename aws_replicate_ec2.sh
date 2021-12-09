#!/bin/bash
#
# aws_replicate_ec2.sh
#
# Quick and dirty example on how to clone of a EC2 instance for test purposes.
# There are better ways to test OS changes in production environments, 
# the truth though is that you don't always have a perfect infrastructure!
# This script replicates an EC2 AWS instance using the AWS cli.
#
# Usage:
#   ./aws_replicate_ec2.sh [instance id]
# Requirements:
#   - aws cli (brew install aws-cli@2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html#cliv2-linux-install)
#   - jq (brew install jq | yum install jq) 
#   - netcat (yum install nc)
#   - create aws cli profiles (aws configure --profile SRC_PROFILE; aws configure --profile test) 
#   - in the EC2 instance you'll have to set an ~/.ssh/config entry in order to access the test server. 
#     You could allocate an elastic IP just for test instances. Example of ~/.ssh/config :
#       host server_name-test
#       User ec2-user           
#       HostName XX.WW.YY.ZZ
#       StrictHostKeyChecking no
#       IdentityFile ~/.ssh/AWS/server_key.pem
#   - script configuration below
#
# The following are the steps of the script:
#   - Deregister old AMI with TEST tag
#   - Create new AMI from instance chosen
#   - Initialize new AMI
#   - Wait for AMI ready
#   - Grant AMI permission to destination account
#   - Launch test instance
#   - Settings tags
#   - Elasic IP association
#   - Waiting for OS and ssh to load
#   - Change httpd configuration in /etc/httpd/sites-available/*
#   - Change Mediawiki configuration
#   - Change Wordpress configuration
#   - Launch daemons
#   - Create script to terminate ec2 replica instance
#
#   MISSING:
#   - Add basic authentication to test sites
#   - Cleanup of AMIs
# _________________________________________________________________

# SCRIPT CONFIGURATION START
region=us-east-1                            # Set the region of the EC2 instance
terminate_script_name=terminate_TEST_ec2.sh

# SOURCE account variables
aws_profile_src=SRC_PROFILE                 # See above on requirements
instance_id=i-0145c27c6b8d962ef             # Set the instance id
src_instance_name=`aws --region=$region --profile $aws_profile_src ec2 describe-instances --instance-ids $instance_id --output text --query Reservations[].Instances[].[KeyName]`

# TARGET account variables  
aws_profile_dst=DST_PROFILE                 # See above on requirements
elastic_ip_addr=XX.WW.YY.ZZ                 # Elastic IP address
elastic_ip_id=eipalloc-0baf9d07abd8f689a    # Set the elastic IP id
dst_account=514567229089                    # Set the destination account number
security_group=sg-0a5f48ea93378cee0         # Set AWS security group id
subnet_group=subnet-d2394ce7                # Set AWS subnet group id
instance_class=`aws --region=$region --profile $aws_profile_src ec2 describe-instances --instance-ids $instance_id --output text --query Reservations[].Instances[].[InstanceType]`
keypair=private_key                         
dst_instance_name="${src_instance_name}_TEST"
user_at_test_server=ec2-user@server_name-test  # ssh/.config of server, see above in requirements
# SCRIPT CONFIGURATION END

#
#   FUNCTIONS START
#
# eg: wait-for-ami-status available
function wait-for-ami-status {
    wheel="/-\|"
    instance=$instance_id
    target_status=$1
    status=unknown
    while [[ "$status" != "$target_status" ]]; do
        status=`aws --region=$region --profile $aws_profile_src ec2 describe-images --owners self --filters "Name=name,Values=$dst_instance_name" --output text --query Images[].[State]`
        # sleep 5
        for (( i=0; i<${#wheel}; i++ )); do
            sleep 1
            echo -en "${wheel:$i:1}" "\r"
        done
    done
}

# eg: wait-for-ec2-status running
function wait-for-ec2-status {
    wheel="/-\|"
    test_instance=$test_instance_id
    target_status=$1
    status=unknown
    while [[ "$status" != "$target_status" ]]; do
        status=`aws --region=$region --profile $aws_profile_dst ec2 describe-instances --instance-ids $test_instance --output text --query Reservations[].Instances[].State.Name`
        #sleep 5
        for (( i=0; i<${#wheel}; i++ )); do
            sleep 1
            echo -en "${wheel:$i:1}" "\r"
        done
    done
}

# eg: wait-for-ssh
function wait-for-ssh {
    wheel="/-\|"
    #echo "Testing instance id: $test_instance_id"
    test_instance=$test_instance_id
    target_status=0
    status=unknown
    while [[ "$status" != "$target_status" ]]; do
        nc -z $elastic_ip_addr 22 > /dev/null
        status=$?
        #echo "Testing instance SSH status: $status"
        for (( i=0; i<${#wheel}; i++ )); do
            sleep 1
            echo -en "${wheel:$i:1}" "\r"
        done
    done
}

# eg: wait-for-status available
function wait-for-status {
    instance=$instance_id
    target_status=$1
    status=unknown
    while [[ "$status" != "$target_status" ]]; do
        status=`aws rds describe-db-instances \
            --db-instance-identifier $instance | head -n 1 \
            | awk -F \  '{print $10}'`
        sleep 5
    done
}

# eg: wait-until-deleted
function wait-until-deleted {
    instance=$instance_id
    count=1
    while [[ "$count" != "0" ]]; do
        count=`aws rds describe-db-instances \
            --db-instance-identifier $instance 2>/dev/null \
            | grep DBINSTANCES \
            | wc -l`
        sleep 5
    done
}

#
#   SCRIPT START
#

old_ami_id=`aws --region=$region --profile $aws_profile_src ec2 describe-images --owners self --filters "Name=name,Values=$dst_instance_name" --output text --query Images[].[ImageId]`
if [ -z "$old_ami_id" ]
then
    echo "Old AMI not present"
else
    echo "Deregister old AMI with name $dst_instance_name and id $old_ami_id"
    aws --region=$region --profile $aws_profile_src ec2 deregister-image --image-id $old_ami_id
fi

echo "Creating new AMI from instance $instance_id"

ami_id=`aws --region=$region --profile $aws_profile_src ec2 create-image --no-reboot --instance-id $instance_id --name $dst_instance_name --output text --query [ImageId]`

echo "Initiating new AMI with id $ami_id"

wait-for-ami-status available

echo "AMI with id $ami_id is Ready"

aws --profile $aws_profile_src --region=$region ec2 modify-image-attribute --image-id $ami_id --launch-permission "Add=[{UserId=$dst_account}]"

echo "Granted permission of new AMI to destination account"

# aws --region=$region ec2 describe-images --executable-users all 

echo "Launching test instance"

instance_json=$(aws --profile $aws_profile_dst --region=$region ec2 run-instances --image-id $ami_id --count 1 --instance-type $instance_class --key-name $keypair --security-group-ids $security_group)
test_instance_id=$(echo $instance_json |  jq -r ".Instances[].InstanceId")

wait-for-ec2-status running

echo "Setting instance Tag name $dst_instance_name"
aws --profile $aws_profile_dst --region=$region ec2 create-tags --resources $test_instance_id --tag Key=Name,Value=$dst_instance_name

echo "Elastic IP association to new instance ( $elastic_ip_addr )"
aws --profile $aws_profile_dst --region=$region ec2 associate-address --instance-id $test_instance_id --allocation-id $elastic_ip_id	

echo "Waiting for instance to load system and ssh daemon"
wait-for-ssh

# CHANGE THE FOLLOWING CONFIGURATION:

echo ''
echo "Change httpd configuration to set test URLs (e.g. test.domain.org)"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo sed -i 's/\.domain\.org/-test\.domain\.org/g' /etc/httpd/sites-available/*" > /dev/null 2>&1
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo sed -i 's/\.domain\.org/-test\.domain\.org/g' /etc/httpd/conf.d/vhost.conf" > /dev/null 2>&1
echo "Change WikiMediaFarm settings"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo sed -i 's/\.domain\.org/-test\.domain\.org/g' /mnt/domain/websites/MediawikiFarm/LocalSettings.php" > /dev/null 2>&1
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo sed -i 's/commons-test\.domain\.org/commons\.domain\.org/g' /mnt/domain/websites/MediawikiFarm/LocalSettings.php" > /dev/null 2>&1

echo "Change Wordpress configuration to set test URLs (WP_HOME & WP_SITEURL)"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo sed -i 's/\domain\.org/test\.domain\.org/g' /var/www/html/one/wp-config.php" > /dev/null 2>&1

#mysql -u(username) -p(password) (the name of the database) -e "DELETE FROM `wp_posts` WHERE `post_type` = "attachment""

echo "Change Wordpress configuration to set test URLs (Database)"
mysql -uUser -pPassword wp_production << eof
    UPDATE wp_options SET option_value = replace(option_value, 'https://domain.org', 'https://test.domain.org') WHERE option_name = 'home' OR option_name = 'siteurl';
    UPDATE wp_posts SET guid = replace(guid, 'https://domain.org','https://test.domain.org');
    UPDATE wp_posts SET post_content = replace(post_content, 'https://domain.org', 'https://test.domain.org');
    UPDATE wp_postmeta SET meta_value = replace(meta_value, 'https://domain.org', 'https://test.domain.org');
eof

echo "Start httpd"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo service httpd restart " > /dev/null 2>&1
echo "Start mysqld"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo service mysqld restart" > /dev/null 2>&1
echo "Start memcached"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo /home/ec2-user/wiki-memcache.sh& > /dev/null 2>&1" > /dev/null 2>&1
echo "Start elastic search"
ssh -o StrictHostKeyChecking=no $user_at_test_server "/home/ec2-user/elasticsearch-start.sh > /dev/null 2>&1" > /dev/null 2>&1

#CONF_FILE=./$target/LocalSettings.php
#sed -i 's/terdzod.domain.org/terdzod-test.domain.org/' $CONF_FILE
# echo "Wiki maintenance update of databases"
#     php ./$target/maintenance/update.php --wiki mediawikifarm_1
#     php ./$target/maintenance/update.php --wiki mediawikifarm_2
#     php ./$target/maintenance/update.php --wiki mediawikifarm_3
#     php ./$target/maintenance/update.php --wiki mediawikifarm_4
#     php ./$target/maintenance/update.php --wiki mediawikifarm_5

#     echo "Adding basic access authorization file"
#     echo "AuthType Basic" > ./$target/.htaccess
#     echo "AuthName \"Password Protected Area\"" >> ./$target/.htaccess
#     echo "AuthUserFile /mnt/centaurdata/websites/.htpasswd" >> ./$target/.htaccess
#     echo "Require valid-user" >> ./$target/.htaccess
#     chown apache:apache ./$target/.htaccess
 
echo "Change host name"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo sed -i 's/\.domain\.org/-TEST\.domain\.org/g' /etc/sysconfig/network" > /dev/null 2>&1

echo "Creating termination script"
echo "#!/bin/bash" > ./$terminate_script_name

cat <<EOT >> ./$terminate_script_name
# eg: wait-for-ec2-status running
function wait-for-ec2-status {
    wheel="/-\|"
    test_instance=$test_instance_id
    target_status=\$1
    status=unknown
    while [[ "\$status" != "\$target_status" ]]; do
        status=\`aws --region=$region --profile $aws_profile_dst ec2 describe-instances --instance-ids $test_instance --output text --query Reservations[].Instances[].State.Name\`
        #sleep 5
        for (( i=0; i<\${#wheel}; i++ )); do
            sleep 1
            echo -en "\${wheel:\$i:1}" "\r"
        done
    done
}
EOT

echo "aws --profile $aws_profile_dst --region=$region ec2 stop-instances --instance-ids $test_instance_id > /dev/null 2>&1" >> ./$terminate_script_name 
echo 'echo "Waiting for instance to stop"' >> ./$terminate_script_name 
echo "wait-for-ec2-status stopped" >> ./$terminate_script_name 
volumes=`aws --region=$region --profile $aws_profile_dst ec2 describe-instances --instance-ids $test_instance_id --output text --query Reservations[].Instances[].[BlockDeviceMappings][][][Ebs][].VolumeId`
echo "aws --profile $aws_profile_dst --region=$region ec2 terminate-instances --instance-ids $test_instance_id > /dev/null 2>&1" >> ./$terminate_script_name 
echo 'echo "Waiting for instance to terminate"' >> ./$terminate_script_name 
echo "wait-for-ec2-status terminated" >> ./$terminate_script_name 
for el in $volumes; do 
    echo "aws --profile $aws_profile_dst --region=$region ec2  delete-volume --volume-id $el" >> ./$terminate_script_name
done

chown root:root ./$terminate_script_name
chmod 700 ./$terminate_script_name
# End termination script

echo "Clone process is complete"

echo "Rebooting test machine to change hostname"
ssh -o StrictHostKeyChecking=no $user_at_test_server "sudo reboot" > /dev/null 2>&1
sleep 5
echo "Waiting for test instance to load system and ssh daemon"
wait-for-ssh

echo "Test clone is ready"
echo "Use the following command to CONNECT to the TEST account:" 
echo ""
echo "  ssh -o StrictHostKeyChecking=no $user_at_test_server"
echo ""
echo "When tests are completed please RUN the following script TO TERMINATE test instance:"
echo ""
echo "  ./$terminate_script_name"
echo ""