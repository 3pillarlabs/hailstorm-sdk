Feature: Process commands

  Background: CLI project is already created
    Given I have Hailstorm installed
    And I created the project "console_app"
    And the "console_app" command line processor is ready


  Scenario: Import results by specifying path to *.jtl files
    Given I have a log file on the local filesystem
    When I import results from 'jmeter_log_sample.jtl'
    Then the log file should be imported

  Scenario: Import results from log files in import directory
    Given I have a log file in import directory
    When I import results
    Then the log file should be imported
