Feature: Console Application

  Background: CLI project is already created
    Given I have Hailstorm installed

  @smoke
  Scenario: Start hailstorm CLI, issue a command and exit
    Given I created the project "console_app"
    When I launch the hailstorm console within "console_app" project
    And I type command 'help' and exit
    Then the application should show the response and exit
