- [Bug 1] Web - default instance type in SPA works only in VPC.

- [Story 6] Web - Fetch pricing options from AWS or frozen object which is not created on every request. Related to [Bug 1](Bug 1).

- [Bug 2] Web - without any projects, the project listing page spinner spins forever. Expect to move to New Project dialog.

- [Story 12] Web - move to open project dialog if there's only one project. Actual screen depends on project status. If incomplete - it opens in wizard else the dashboard

- [Task 11] Web - run integration test

- [Story 8] Web - Delete clusters need a different approach with respect to 'remove' when nothing is added 
versus disable after a test has been run with the cluster. Test with multiple amazon clusters in different geo regions.

- [Task 10] Web - implement and test with data center cluster

- [Story 13] Web - delete a project

- [Story 7] Web - Fetch region and AMI map from AWS SDK or frozen object which is not created on every request

- [Story 14] Web - import results

- [Bug 3] Gem - sometimes logs fail to download from the Web interface (exception is in a thread making it hard to track down); but there's no apparent issue.

- [Bug 4] CLI - ``results`` fails in random ways if log collection was not successful for some reason when tests are stopped. Seems to be related to [Bug 3](Bug 3).

- [Task 5] Web - optimize react effects (too many triggered for false positives)
