Feature: Generate report

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is up and accessible in AWS region 'us-east-1'

  @smoke
  @end-to-end
  Scenario: Setup project with 10 threads
    Given the 'cucumber_test' project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-1 |                       |
    And configure target monitoring
    And setup the project
    Then 1 active load agent should exist

  @smoke
  @end-to-end
  Scenario: Start the test with 10 threads
    Given the "cucumber_test" project
    When I start load generation
    Then 1 Jmeter instance should be running

  @smoke
  @end-to-end
  Scenario: Stop the test with 10 threads
    Given the "cucumber_test" project
    When I stop load generation with 'wait'
    Then 1 active load agent should exist
    And 0 Jmeter instances should be running

  @end-to-end
  Scenario: Start test for 20 threads
    Given the "cucumber_test" project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-1 |                       |
    And start load generation
    Then 1 active load agent should exist
    And 1 Jmeter instance should be running

  @end-to-end
  Scenario: Stop the test with 20 threads
    Given the "cucumber_test" project
    When I wait for 200 seconds
    And stop load generation with 'wait'
    Then 1 active load agent should exist
    And 0 Jmeter instances should be running

  @end-to-end
  Scenario: Start test for 30 threads
    Given the "cucumber_test" project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    30 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-1 | 25                    |
    And start load generation
    Then 2 active load agents should exist
    And 2 Jmeter instances should be running

  @end-to-end
  Scenario: Stop the test with 30 threads
    Given the "cucumber_test" project
    When I wait for 200 seconds
    And stop load generation with 'wait'
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  Scenario: Re-execute test for 20 threads
    Given the "cucumber_test" project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-1 | 25                    |
    And start load generation
    Then 1 active load agent should exist
    And 1 Jmeter instance should be running

  Scenario: Stop the new test with 20 threads
    Given the "cucumber_test" project
    When I wait for 200 seconds
    And stop load generation with 'wait'
    Then 1 active load agent should exist
    And 0 Jmeter instances should be running

  Scenario: Abort a test with 10 threads
    Given the "cucumber_test" project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following amazon clusters
      | region    | max_threads_per_agent |
      | us-east-1 | 25                    |
    And start load generation
    And wait for 10 seconds
    And abort the load generation
    Then 0 Jmeter instances should be running
    And 5 total execution cycles should exist
    And 4 reportable execution cycles should exist

  @smoke
  @end-to-end
  Scenario: Terminate tests
    Given the "cucumber_test" project
    When I terminate the setup
    Then 0 load agents should exist

  @smoke
  @end-to-end
  Scenario: Generate a report
    Given the "cucumber_test" project
    When I generate a report
    Then a report file should be created
