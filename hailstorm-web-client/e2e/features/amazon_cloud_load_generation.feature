Feature: Generate load from AWS

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is up and accessible in AWS region 'us-east-1'

  @smoke
  @end-to-end
  Scenario: Start with 10 threads
    When I have Hailstorm open
    And I created the project "Simple burst test"
    And I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | maxThreadsPerAgent |
      | North America/US East (Ohio) | |
    And finalize the configuration
    And start load generation
    Then 1 test should be running

  @smoke
  @end-to-end
  Scenario: Stop the test with 10 threads
    When I wait for load generation to stop
    Then 1 tests should exist

  @end-to-end
  Scenario: Start test for 20 threads
    When I reconfigure the project
    And I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | maxThreadsPerAgent |
      | North America/US East (Ohio) | |
    And finalize the configuration
    And start load generation
    Then 1 test should be running

  @end-to-end
  Scenario: Stop the test with 20 threads
    When I wait for load generation to stop
    Then 2 tests should exist

  @end-to-end
  Scenario: Start test for 30 threads
    When I reconfigure the project
    And I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    30 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | maxThreadsPerAgent    |
      | North America/US East (Ohio) | 25 |
    And finalize the configuration
    And start load generation
    Then 1 test should be running

  @end-to-end
  Scenario: Stop the test with 30 threads
    When I wait for load generation to stop
    Then 3 tests should exist

  Scenario: Abort a test with 10 threads
    When I reconfigure the project
    And I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | maxThreadsPerAgent    |
      | North America/US East (Ohio) | 25 |
    And finalize the configuration
    And start load generation
    And abort the load generation after 60 seconds
    And wait for tests to abort
    Then 3 tests should exist

  @smoke
  @end-to-end
  Scenario: Terminate tests
    When I terminate the setup
    Then 0 load agents should exist

  @smoke
  @end-to-end
  Scenario: Generate a report
    When I generate a report
    Then a report file should be created
