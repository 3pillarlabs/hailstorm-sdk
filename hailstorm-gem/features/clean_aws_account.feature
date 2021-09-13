Feature: Clean AWS Account
  Background: Hailstorm application is initialized
    Given Hailstorm is initialized with a project 'clean_aws_account'

  Scenario: Purge AWS Cluster
    Given an AWS cluster already exists in 'ap-northeast-1' region
    When the AWS cluster is purged
    Then the AWS cluster should be removed
