# RELEASE 1

- [Bug 2] Web - without any projects, the project listing page spinner spins forever. Expect to move to New Project dialog.

- [Task 11] Web - run integration test

- [Story 8] Web - Delete clusters need a different approach with respect to 'remove' when nothing is added 
versus disable after a test has been run with the cluster. Test with multiple amazon clusters in different geo regions.

- [Task 10] Web - implement and test with data center cluster

- [Story 13] Web - delete a project

- [Bug 3] Gem - sometimes logs fail to download from the Web interface (exception is in a thread making it hard to track down); but there's no apparent issue.

- [Bug 4] CLI - ``results`` fails in random ways if log collection was not successful for some reason when tests are stopped. Seems to be related to [Bug 3](Bug 3).

- [Task 16] - Rework how failures are handed in start and stop. Need a "retry" or "auto-retry" capability. [Bug 3](Bug 3), [Bug 4](Bug 4).

- [Story 14] Web - Redo the pricing options based on instances available in a VPC to minimize hourly cost.

- [Task 17] Update the CI pipeline to add unit and integration tests

- [Task 18] Test and document the deployment on an end user's machine.

# BACKLOG

- [Story 12] Web - move to open project dialog if there's only one project. Actual screen depends on project status. If incomplete - it opens in wizard else the dashboard

- [Story 7] Web - Fetch region and AMI map from AWS SDK or frozen object which is not created on every request

- [Story 15] Web - import results

- [Task 5] Web - optimize react effects (too many triggered for false positives)

- [Story 6] Web - Fetch pricing options from AWS or frozen object which is not created on every request.

- [Task 18] Web - while starting a test for the first time, the execution cycle grid shows "No tests to show" till the test starts. Need a different message "Test starting up in few minutes..."

- [Story 19] Web - show errors received in log stream as error messages
