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


Scenario: Create or use an existing base AMI
  Given Amazon is chosen as the cluster
  When I choose 'us-east-1' region
  And the JMeter version for the project is '3.2'
  And create the AMI
  Then an AMI with name '3pg-hailstorm-j3.2-x86_64' should exist

@terminate_instance
Scenario: New Load Agent is created from existing base AMI
  Given Amazon is chosen as the cluster
  And I choose 'us-east-1' region
  And an AMI with name '3pg-hailstorm-j3.2-x86_64' exists
  When I start a new load agent
  Then installed JMeter version should be '3.2'
  And custom properties should be added


