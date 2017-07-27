Feature: Create Amazon Machine Image

  Scenario: Choose the correct AMI for an AWS region
    Given Amazon is chosen as the cluster
    When I choose a region
    Then the AMI should exist for 'us-east-1'
    And for 'us-east-2'
    And for 'us-west-1'
    And for 'us-west-2'
    And for 'ca-central-1'
    And for 'eu-west-1'
    And for 'eu-central-1'
    And for 'eu-west-2'
    And for 'ap-northeast-1'
    And for 'ap-southeast-1'
    And for 'ap-southeast-2'
    And for 'ap-northeast-2'
    And for 'ap-south-1'
    And for 'sa-east-1'
