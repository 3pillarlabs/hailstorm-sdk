Feature: Load generation from physical machines/virtual machines/docker containers in a data center

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is up and accessible at an IP address
    And 2 data center machines are accessible
    And I created the project "hs_data_center_integration"

  @smoke
  @end-to-end
  @focus
  Scenario: Start hailstorm
    When I launch the hailstorm console within "hs_data_center_integration" project
    Then the application should be ready to accept commands

  @smoke
  @end-to-end
  Scenario: Setup project with 10 threads
    Given the "hs_data_center_integration" project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity  |
      | docker-local   | root      | insecure_key  |
    And disable target monitoring
    And I launch the hailstorm console within "hs_data_center_integration" project
    And execute "setup" command
    Then 2 active load agents should exist

  @smoke
  @end-to-end
  Scenario: Start the test with 10 threads
    Given the "hs_data_center_integration" project
    When I execute "start" command
    Then 2 Jmeter instances should be running

  @smoke
  @end-to-end
  Scenario: Stop the test with 10 threads
    Given the "hs_data_center_integration" project
    When I wait for 20 seconds
    When I execute "stop wait" command
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  @end-to-end
  Scenario: Start test for 20 threads
    Given the "hs_data_center_integration" project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity       |
      | docker-local   | root      | insecure_key  |
    And disable target monitoring
    And execute "start" command
    Then 2 active load agents should exist
    And 2 Jmeter instances should be running

  @end-to-end
  Scenario: Stop the test with 20 threads
    Given the "hs_data_center_integration" project
    When I wait for 20 seconds
    And execute "stop wait" command
    Then 2 active load agents should exist
    And 0 Jmeter instances should be running

  Scenario: Abort a test with 10 threads
    Given the "hs_data_center_integration" project
    When I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
    And configure following data center
      | title          | user_name | ssh_identity  |
      | docker-local   | root      | insecure_key  |
    And disable target monitoring
    And execute "start" command
    And wait for 10 seconds
    And execute "abort" command
    Then 0 Jmeter instances should be running
    And 2 active load agents should exist
    And 3 total execution cycles should exist
    And 2 reportable execution cycles should exist

  @smoke
  @end-to-end
  Scenario: Terminate tests
    Given the "hs_data_center_integration" project
    When I execute "terminate" command
    Then 0 load agents should exist

  @smoke
  @end-to-end
  Scenario: Generate a report
    Given the "hs_data_center_integration" project
    When I execute "results report" command
    Then a report file should be created

