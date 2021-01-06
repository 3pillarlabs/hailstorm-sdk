Feature: Handle load generation failure on Amazon Cloud

  Background: Hailstorm application is initialized
    Given Hailstorm is initialized with a project 'aws_setup_failure'

  Scenario: Load generation setup fails due to permanent error
    Given JMeter is correctly configured
    And Cluster is incorrectly configured in 'us-east-1'
    And load generation fails due to a configuration error
    Then the error should not suggest a time period to wait before trying again

  Scenario: Load generation setup fails due to temporary failure on single cluster
    Given JMeter is correctly configured
    And Cluster is correctly configured in 'us-east-1'
    When load generation fails due to a temporary AWS failure
    Then the exception should suggest a time period to wait before trying again

  Scenario: Load generation setup fails due to temporary failure on multiple clusters
    Given JMeter is correctly configured
    And Cluster is correctly configured in 'us-east-1'
    And Cluster is correctly configured in 'us-east-2'
    When load generation fails due to a temporary AWS failure
    Then the exception should suggest a time period to wait before trying again

  @terminate_instance
  Scenario: Load generation fails to start due to temporary failure to start an instance
    Given JMeter is correctly configured
    And Cluster is correctly configured in 'us-east-1'
    And Cluster is correctly configured in 'us-east-2'
    And each cluster has 2 load agents
    When load generation fails due to a temporary AWS instance failure
    Then the other load agents should still be created
