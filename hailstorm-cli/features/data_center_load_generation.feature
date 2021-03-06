Feature: Load generation from physical machines/virtual machines/docker containers in a data center

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is up and accessible at "192.168.20.100"
    And data center machines are accessible
      | host          |
      | 192.168.20.10 |
      | 192.168.20.20 |
    And I have Hailstorm installed
    And I created the project "hs_data_center_integration"
    And the "hs_data_center_integration" command line processor is ready

  @smoke
  @end-to-end
  Scenario: Setup project with 10 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity  | machines |
      | docker-local   | root      | insecure_key  | 192.168.20.10,192.168.20.20 |
    And finalize the configuration
    And setup the project
    Then 2 active load agents should exist

  @smoke
  @end-to-end
  Scenario: Start the test with 10 threads
    When I start load generation
    Then 2 Jmeter instances should be running

  @smoke
  @end-to-end
  Scenario: Stop the test with 10 threads
    When I wait for load generation to stop
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  @end-to-end
  Scenario: Start test for 20 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity  | machines |
      | docker-local   | root      | insecure_key  | 192.168.20.10,192.168.20.20 |
    And finalize the configuration
    And start load generation
    Then 2 active load agents should exist
    And 2 Jmeter instances should be running

  @end-to-end
  Scenario: Stop the test with 20 threads
    When I wait for load generation to stop
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  Scenario: Abort a test with 10 threads
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity  | machines |
      | docker-local   | root      | insecure_key  | 192.168.20.10,192.168.20.20 |
    And finalize the configuration
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
    When I terminate the setup
    Then 0 load agents should exist

  @smoke
  @end-to-end
  Scenario: Generate a report
    When I generate a report
    Then a report file should be created

