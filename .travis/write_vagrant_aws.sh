#!/bin/sh

cat - > ${TRAVIS_BUILD_DIR}/setup/hailstorm-site/vagrant-site.yml <<EOF
# Configuration for Vagrant aws VM
---
  keypair_name: "${AWS_SITE_KEY_PAIR}"
  #instance_type: "t2.medium"
  #region: "us-east-1"
  security_groups: ["${AWS_SITE_SECURITY_GROUP}"]
  subnet_id: "${AWS_SITE_SUBNET_ID}"
  private_key_path: "${AWS_SITE_KEY_PAIR}.pem"
EOF
