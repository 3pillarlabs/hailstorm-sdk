Feature: Load generation from physical machines/virtual machines/docker containers in a data center

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is up and accessible at "192.168.20.100"
    And data center machines are accessible
      | host          |
      | 192.168.20.10 |
      | 192.168.20.20 |

  @smoke
  @end-to-end
  Scenario: Start the test with 10 threads
    When I have Hailstorm open
    And I created the project "Simple DC burst test"
    And I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    10 |
      | Duration       |   180 |
      | RampUp         |     0 |
      | ServerName     |    dc |
    And configure following data center
      | title          | userName | sshIdentity  | machines |
      | docker-local   | root     | insecure_key | 192.168.20.10,192.168.20.20 |
    And finalize the configuration
    And start load generation
    Then 1 test should be running
    And 2 load agents should exist

  @smoke
  @end-to-end
  Scenario: Stop the test with 10 threads
    Given a test is running
    When I wait for load generation to stop
    Then 1 test should exist

  @smoke
  @end-to-end
  Scenario: Start test for 20 threads
    When I reconfigure the project
    And I configure JMeter with following properties
      | property       | value |
      | NumUsers       |    20 |
      | Duration       |   180 |
      | RampUp         |     0 |
      | ServerName     |    dc |
    And configure following data center
      | title          | userName | sshIdentity  | machines |
      | docker-local   | root     | insecure_key | 192.168.20.10,192.168.20.20 |
    And finalize the configuration
    And start load generation
    Then 1 test should be running
    And 2 load agents should exist

  @smoke
  @end-to-end
  Scenario: Stop the test with 20 threads
    When I wait for load generation to stop
    Then 2 tests should exist

  @smoke
  @end-to-end
  Scenario: Terminate tests
    When I terminate the setup
    Then 0 load agents should exist

  @smoke
  @end-to-end
  Scenario: Generate a report
    Given some tests have completed
    When I generate a report
    Then a report file should be created
