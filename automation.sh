#!/bin/bash

# Install AWS CLI
sudo apt-get update
sudo apt-get install -y awscli
 
echo "describe passed" 
INSTANCE_IDS=$(aws ec2 describe-instances --filters "Name=tag:envvar,Values=dev" --query 'Reservations[*].Instances[*].InstanceId' --output text)

 echo "instance id is : $INSTANCE_IDS"

 TARGET_GROUP_ARN='arn:aws:elasticloadbalancing:us-west-2:628725545865:targetgroup/demo-tg-1/1686f42d31bfc249'
 echo "$TARGET_GROUP_ARN"

for instance_id in $INSTANCE_IDS
do
        echo "starting deregistration process"
        aws elbv2 deregister-targets --target-group-arn $TARGET_GROUP_ARN --targets Id=$instance_id
        # HEALTH_STATUS=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --targets Id=$instance_id | jq -r '.TargetHealthDescriptions[0].TargetHealth.State')
        # echo "$HEALTH_STATUS"
        MAX_RETRIES=15
        WAIT_TIME=30
        retry_count=0
        while [ $retry_count -lt $MAX_RETRIES ]; do
         HEALTH_STATUS=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --targets Id=$instance_id | jq -r '.TargetHealthDescriptions[0].TargetHealth.State')
         echo "$HEALTH_STATUS"
          if [ "$HEALTH_STATUS" = "unused" ]; then
             echo "Target health is unused. Deregistration complete."
             break
          else
             echo "Target health is $HEALTH_STATUS. Waiting for $WAIT_TIME seconds before retry..."
             sleep $WAIT_TIME
             retry_count=$((retry_count + 1))
          fi
          echo "$retry_count"
     done
        # if [ $retry_count -ge $MAX_RETRIES ]; then
        #      echo "Max retries reached. Exiting..."
        # fi
        ls -la
        echo "started connection to ec2 instance"
        echo $EC2_PRIVATE_KEY
        echo "$EC2_PRIVATE_KEY" > key.pem
        chmod 600 key.pem
        echo "$key.pem"
        cat key.pem
        dns_name=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[*].Instances[*].PublicDnsName' --output text)
        echo $dns_name
        ssh -o StrictHostKeyChecking=no -i key.pem ubuntu@$dns_name << EOF
        sudo su -
        source myenv/bin/activate
        lsof -n -i :3000 | grep LISTEN
        pkill 'uvicorn'
        echo "process killed"
        sleep 15
        nohup uvicorn ap:app --host 0.0.0.0 --port 3000  --reload > /dev/null 2>&1 & exit
        ls -la
        echo "successfully exited"
        exit
EOF
     sleep 5
     echo "out of ec2 instance"
     aws elbv2 register-targets --target-group-arn $TARGET_GROUP_ARN --targets Id=$instance_id
     sleep 60
done
