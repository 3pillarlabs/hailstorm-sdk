Feature: Only generate report

  Background: Tests have already been run outside of Hailstorm and the log (*.jtl) are available.

    Scenario: Import one log file
      Given the "only_report_generation" project
      When I configure JMeter with following properties
        | property       | value |
        | NumUsers       |    10 |
        | Duration       |   180 |
        | RampUp         |     0 |
      And configure following amazon clusters
        | region    | max_threads_per_agent |  active |
        | us-east-1 |                       |  false  |
      And import results from '../../data/jmeter_log_sample.jtl'
      Then 1 reportable execution cycle should exist

    Scenario: Generate report
      Given the "only_report_generation" project
      When I generate a report
      Then a report file should be created