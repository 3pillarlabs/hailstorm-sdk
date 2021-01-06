Feature: Handle load generation failure on Data Center

  Background: Hailstorm application is initialized
    Given Hailstorm is initialized with a project 'dc_setup_failure'

  Scenario: Load generation on data center fails due to missing Java or incorrect version
    Given JMeter is correctly configured
    And Data center is correctly configured with multiple agents
    When load generation fails on one agent due to missing Java or incorrect version
    Then other agents should be configured and saved

  Scenario: Load generation on data center fails due to unreachable agent
    Given JMeter is correctly configured
    And Data center is correctly configured with multiple agents
    When load generation fails on one agent due to unreachable agent
    Then other agents should be configured and saved

  Scenario: Load generation on data center fails due to missing JMeter or incorrect version
    Given JMeter is correctly configured
    And Data center is correctly configured with multiple agents
    When load generation fails on one agent due to missing JMeter or incorrect version
    Then other agents should be configured and saved
