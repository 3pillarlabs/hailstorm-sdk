Feature: Load generation from physical machines/virtual machines/docker containers in a data center

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is up and accessible at an IP address
    And 2 data center machines are accessible
    And Hailstorm is initialized with a project 'hs_data_center_integration'

  @smoke
  @end-to-end
  Scenario: Setup project with 10 threads
    Given the 'hs_data_center_integration' project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity  |
      | docker-local   | root      | insecure_key  |
    And setup the project
    Then 2 active load agents should exist

  @smoke
  @end-to-end
  Scenario: Start the test with 10 threads
    Given the 'hs_data_center_integration' project
    When I start load generation
    Then 2 Jmeter instances should be running

  @smoke
  @end-to-end
  Scenario: Stop the test with 10 threads
    Given the 'hs_data_center_integration' project
    When I wait for 20 seconds
    When I stop load generation with 'wait'
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  @end-to-end
  Scenario: Start test for 20 threads
    Given the 'hs_data_center_integration' project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity       |
      | docker-local   | root      | insecure_key  |
    And start load generation
    Then 2 active load agents should exist
    And 2 Jmeter instances should be running

  @end-to-end
  Scenario: Stop the test with 20 threads
    Given the 'hs_data_center_integration' project
    When I wait for 20 seconds
    And I stop load generation with 'wait'
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  Scenario: Abort a test with 10 threads
    Given the 'hs_data_center_integration' project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity  |
      | docker-local   | root      | insecure_key  |
    And start load generation
    And wait for 10 seconds
    And abort the load generation
    Then 0 Jmeter instances should be running
    And 2 active load agents should exist
    And 3 total execution cycles should exist
    And 2 reportable execution cycles should exist

  @smoke
  @end-to-end
  Scenario: Terminate tests
    Given the 'hs_data_center_integration' project
    When I terminate the setup
    Then 0 load agents should exist

  @smoke
  @end-to-end
  Scenario: Generate a report
    Given the 'hs_data_center_integration' project
    When I generate a report
    Then a report file should be created

