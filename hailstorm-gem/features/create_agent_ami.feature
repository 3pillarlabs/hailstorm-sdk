  Feature: Create Amazon Machine Image

  Background: Hailstorm application is initialized
    Given Hailstorm is initialized with a project 'create_agent_ami'

  Scenario Outline: Choose the correct AMI for an AWS region
    Given Amazon is chosen as the cluster
    When I choose '<region>' region
    Then the AMI should exist

    Examples:
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


  @smoke
  Scenario: Create or use an existing base AMI
    Given Amazon is chosen as the cluster
    When I choose 'us-east-1' region
    And there is no AMI with name '3pg-hailstorm-j5.2.1-x86_64-gem_integration'
    And the JMeter version for the project is '5.2.1'
    And a public VPC subnet is available
    And create the AMI
    Then an AMI with name '3pg-hailstorm-j5.2.1-x86_64-gem_integration' should exist

  @terminate_instance
  @smoke
  Scenario: New Load Agent is created from existing base AMI
    Given Amazon is chosen as the cluster
    And I choose 'us-east-1' region
    And a public VPC subnet is available
    And instance type is 't2.small'
    And an AMI with name '3pg-hailstorm-j5.2.1-x86_64-gem_integration' exists
    When I start a new load agent
    Then installed JMeter version should be '5.2.1'
    And custom properties should be added
