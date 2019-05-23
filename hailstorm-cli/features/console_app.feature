Feature: Console Application

  Background: Application for measuring performance is up and accessible
    Given 'Hailstorm Site' is configured correctly

  @smoke
  Scenario: Create a new project
    Given I have hailstorm installed
    When I create a new project "console_app" from the cli
    Then the project structure for "console_app" should be created

  @smoke
  Scenario: Start hailstorm
    Given I have Hailstorm installed
    When I launch the hailstorm console within "console_app" project from the cli
    Then the application should be ready to accept command "help"

  @smoke
  Scenario: Exit hailstorm
    When I give command 'exit'
    Then the application should exit

  Scenario: Execute a command over existing project
    Given I have hailstorm installed
    When I create a new project "console_app" from the cli
    And the "console_app" project is active
    Then the application should execute command "help"
    And the application should execute command "results"
