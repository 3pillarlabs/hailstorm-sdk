Feature: Clean AWS Account
  Background: Hailstorm application is initialized
    Given Hailstorm is initialized with a project 'clean_aws_account'

  Scenario: Purge a previously deleted AWS cluster
    Given a previously deleted AWS cluster is configured in any region
    When the AWS cluster is purged
    Then the AMI is deleted from the AWS cluster model

  @delete_untagged_resources
  Scenario: Purge an AWS cluster with untagged resources
    Given AWS untagged resources with prefix 'purge-aws-account-feature' in a region with a public subnet
    And an AWS cluster configured with these resources
    When the AWS cluster is purged
    Then the AMI is deleted from the AWS cluster model
    But the AWS resources are not deleted

  Scenario: Purge an AWS cluster with tagged resources
    Given JMeter is correctly configured
    And an AWS cluster and resources created by Hailstorm in a clean region
    And the created resources are tagged
    When the AWS cluster is purged
    Then the AMI is deleted from the AWS cluster model
    And the AWS resources are deleted as well
