Feature: Create Amazon Machine Image

  Scenario: Choose the correct AMI for an AWS region
    Given Amazon is chosen as the cluster
    When I choose the following regions
      |region|
      |us-east-1|
      |us-east-2|
      |us-west-1|
      |us-west-2|
      |ca-central-1|
      |eu-west-1|
      |eu-central-1|
      |eu-west-2|
      |ap-northeast-1|
      |ap-southeast-1|
      |ap-southeast-2|
      |ap-northeast-2|
      |ap-south-1|
      |sa-east-1|
    Then the AMI should exist
