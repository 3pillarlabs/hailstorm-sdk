Feature: Generate load from AWS

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is up and accessible in AWS region 'us-east-1'
    And I have Hailstorm installed
    And I created the project "cucumber_test"
    And the "cucumber_test" command line processor is ready

  @smoke
  @end-to-end
  @aws
  Scenario: Setup project with 10 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-2 |                       |
    And finalize the configuration
    And setup the project
    Then 1 active load agent should exist

  @smoke
  @end-to-end
  @aws
  Scenario: Start the test with 10 threads
    When I start load generation
    Then 1 Jmeter instance should be running

  @smoke
  @end-to-end
  @aws
  Scenario: Stop the test with 10 threads
    When I wait for load generation to stop
    Then 1 active load agent should exist
    And 0 Jmeter instances should be running

  @smoke
  @end-to-end
  @aws
  Scenario: Start test for 20 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-2 |                       |
    And finalize the configuration
    And start load generation
    Then 1 active load agent should exist
    And 1 Jmeter instance should be running

  @smoke
  @end-to-end
  @aws
  Scenario: Stop the test with 20 threads
    When I wait for load generation to stop
    Then 1 active load agent should exist
    And 0 Jmeter instances should be running

  @smoke
  @end-to-end
  @aws
  Scenario: Start test for 30 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    30 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-2 | 25                    |
    And finalize the configuration
    And start load generation
    Then 2 active load agents should exist
    And 2 Jmeter instances should be running

  @smoke
  @end-to-end
  @aws
  Scenario: Stop the test with 30 threads
    When I wait for load generation to stop
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  @aws
  Scenario: Re-execute test for 20 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-2 | 25                    |
    And finalize the configuration
    And start load generation
    Then 1 active load agent should exist
    And 1 Jmeter instance should be running

  @aws
  Scenario: Stop the new test with 20 threads
    When I wait for load generation to stop
    Then 1 active load agent should exist
    And 0 Jmeter instances should be running

  @aws
  Scenario: Abort a test with 10 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-2 | 25                    |
    And finalize the configuration
    And start load generation
    And wait for 10 seconds
    And abort the load generation
    Then 0 Jmeter instances should be running
    And 5 total execution cycles should exist
    And 4 reportable execution cycles should exist

  @smoke
  @end-to-end
  @aws
  Scenario: Terminate tests
    When I terminate the setup
    Then 0 load agents should exist

  @smoke
  @end-to-end
  @aws
  Scenario: Generate a report
    When I generate a report
    Then a report file should be created
