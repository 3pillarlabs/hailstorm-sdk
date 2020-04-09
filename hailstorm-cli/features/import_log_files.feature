Feature: Import log files and generate report

  Background: Tests have already been run outside of Hailstorm and the log (*.jtl) are available.
    Given I have Hailstorm installed
    And I created the project "console_app"
    And the "console_app" command line processor is ready

  Scenario: Import one log file with path argument
    Given I have a log file on the local filesystem
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |  active |
      | us-east-1 |                       |  false  |
    And I import results from 'jmeter_log_sample.jtl'
    Then 1 log file should be imported

  Scenario: Import one log file from default import directory
    Given I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |  active |
      | us-east-1 |                       |  false  |
    When I copy 'jmeter_log_sample.jtl' to default import directory
    And I import results
    Then 2 log files should be imported

  Scenario: Generate report
    When I generate a report
    Then a report file should be created