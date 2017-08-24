---
layout: page
title: About
permalink: /about/
---

### Overview

Hailstorm is a cloud-based load generation application capable of generating massive amounts of load on a test system and monitoring performance counters on test system components. Hailstorm uses Apache JMeter to generate the load on the system under test. The application provides a command-line interface (CLI) and web based user interface to configure the test environment, start tests, stop tests and generate reports. Behind the scenes, the application uses Amazon EC2 to create load agents.

### Motivation

In a well-executed product development cycle, the components within the product architecture are interconnected at least mid-way through the development phase. At this point, QA is able to start executing integration tests to test epics or workflows composed of different user stories that were individually tested earlier in the test cycle. This is the ideal time to start thinking of the load characteristics of the application and questions like:

- What would the normal load be?
- What would the peak load be?
- Do you foresee any spikes?

The stakeholders define these starting metrics and QA builds performance tests to measure the application response time and resource usage. JMeter is a popular open source tool that QA teams often use to devise these tests. JMeter makes it easy to get started and devise the plans for different kinds of performance tests. We have found that JMeter running on one machine is suitable for up to 50-100 virtual users (threads), and this is ideal for the initial stages of the performance tests. However, as we go beyond this range, the single machine’s processors and IO bandwidth are fully consumed, which caps out the requests/second. After a threshold, increasing the number of threads has no affect on the number of requests that can be sent in a fixed time boundary.

At this point you need to use more than one machine, and this is where JMeter can get pretty complex and in need of manual intervention.

### rescue Hailstorm

Hailstorm takes over the complexity of running tests on multiple machines, collating the logs and producing aggregated reports. This is what you can do with Hailstorm:

- Run one or more JMeter scripts in parallel or serial order. Each script can use multiple thread groups to emulate different actions and different user groups.
- Utilize one or more Amazon Clouds (suitably located at different geographic locations) or physical data centers as load clusters.
- Scale the load generated from each cluster limitlessly by using one or more Amazon accounts.
- Include one or more servers for monitoring resource utilization. The servers can be grouped into different groups such as ‘Web Server’, ‘Database Master’, ‘Database Slave’ etc.; this can be completely customized.
- Generate editable reports in Microsoft Word (.docx).
- Use the offline mode design of the application to launch long running endurance tests.

You also get some great graphs like this one:

![Hailstorm sample page requests time breakup]({{ site.url }}{{ site.baseurl }}/images/hailstorm-sample-page-req-breakup.png)

### Technology

Hailstorm is written in Ruby and uses the JRuby platform for integration with Java libraries and robust multi-threading. The core component is the Ruby gem which has a command line interface (CLI). The same library is used by a web user interface which makes it easier to configure and use Hailstorm.
