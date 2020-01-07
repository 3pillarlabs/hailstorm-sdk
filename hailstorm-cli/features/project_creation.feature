Feature: Project Creation

  @smoke
  Scenario: Create a new CLI project
    Given I have Hailstorm installed
    When I create a new project "console_app"
    Then the project structure for "console_app" should be created
