#!/bin/bash
# Install AWS CLI
sudo apt-get update
sudo apt-get install -y awscli
echo "describe passed"
 
TARGET_GROUP_ARN='arn:aws:elasticloadbalancing:eu-west-1:508308164161:targetgroup/automation-alb-tg/28f6ebf3091af7af arn:aws:elasticloadbalancing:eu-west-1:508308164161:targetgroup/Automation-2-tg/3d033d2423040818'
echo "target group arn is :$TARGET_GROUP_ARN"
 
INSTANCE_IDS=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN | jq -r '.TargetHealthDescriptions[].Target.Id')
echo "instance id is : $INSTANCE_IDS"
 
for target_group_arn in $TARGET_GROUP_ARN
do
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
       # sleep 60
       REGISTER_MAX_RETRIES=10
       REGISTER_WAIT_TIME=10
       register_retry_count=0
      while [ $register_retry_count -lt $REGISTER_MAX_RETRIES ]; do
        REGISTER_HEALTH_STATUS=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --targets Id=$instance_id | jq -r '.TargetHealthDescriptions[0].TargetHealth.State')
        echo "$REGISTER_HEALTH_STATUS"
      if [ "$REGISTER_HEALTH_STATUS" = "healthy" ]; then
          echo "Target health is healthy. Deregistration complete."
          break
      elif [ "$REGISTER_HEALTH_STATUS" = "initial" ]; then
          echo "Target health is $REGISTER_HEALTH_STATUS. Waiting for $REGISTER_WAIT_TIME seconds before retry..."
          sleep $REGISTER_WAIT_TIME
          register_retry_count=$((register_retry_count + 1))
      else
          echo "Target health is $REGISTER_HEALTH_STATUS. Exiting."
          exit 1
      fi
      echo "$register_retry_count"
    done
done
    done
