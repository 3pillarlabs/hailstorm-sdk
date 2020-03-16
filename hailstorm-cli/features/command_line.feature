Feature: Process commands one at a time

  Background: CLI project is already created
    Given I have Hailstorm installed
    And I created the project "console_app"
    And the "console_app" command line processor is ready


  Scenario: See current setup
    When I capture the output of the command "show"
    Then output should be shown

  Scenario: Setup with inactive cluster and monitoring
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |  active |
      | us-east-1 |                       |  false  |
    And finalize the configuration
    And capture the output of the command "setup"
    Then output should be shown

  Scenario: View active elements
    When I capture the output of the command "show"
    Then output should not be shown matching "us-east-1"

  Scenario: View all elements
    When I capture the output of the command "show all"
    Then output should be shown matching "us-east-1"
