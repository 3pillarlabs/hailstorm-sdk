Feature: VPC support

  Background: Hailstorm application is initialized
    Given Hailstorm is initialized with a project 'amazon_vpc_support'

  Scenario: Create or use an existing base AMI
    Given Amazon is chosen as the cluster
    When I choose 'us-east-1' region
    And the JMeter version for the project is '3.2'
    And a public VPC subnet is available
    And create the AMI
    Then an AMI with name '3pg-hailstorm-j3.2-x86_64' should exist

  @terminate_instance
  @smoke
  Scenario: New Load Agent is created from existing base AMI
    Given Amazon is chosen as the cluster
    And I choose 'us-east-1' region
    And a public VPC subnet is available
    And instance type is 't2.small'
    And an AMI with name '3pg-hailstorm-j3.2-x86_64' exists
    When I start a new load agent
    Then installed JMeter version should be '3.2'
