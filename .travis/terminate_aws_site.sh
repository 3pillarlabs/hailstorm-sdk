#!/bin/sh

instances=$(aws ec2 describe-instances \
--filters Name=tag:Name,Values='Vagrant - Hailstorm Site' \
          Name=instance-state-name,Values=running \
--query Reservations[*].Instances[*].InstanceId \
--output text)

if [ -n "${instances}" ]; then
  aws ec2 terminate-instances --instance-ids ${instances}
fi
