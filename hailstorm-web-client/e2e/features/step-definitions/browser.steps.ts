import { Given, When, Then } from "cucumber";
import { expect } from 'chai';
import {
  landingPage,
  newProjectWizardPage,
  jMeterConfigPage,
  amazonConfig,
  wizardReview,
  projectWorkspace
} from "features/support/po";

Given("I have Hailstorm open", function() {
  landingPage.open();
  const title = landingPage.getTitle();
  expect(title).to.match(/hailstorm/i);
});

Given("I created the project {string}", function(projectTitle: string) {
  const projectElement = landingPage.findProjectElement({title: projectTitle});
  if (projectElement) {
    newProjectWizardPage.proceedToNextStep(projectElement);

  } else {
    newProjectWizardPage.createNewProject({title: projectTitle});
  }
});

When("I configure JMeter with following properties", function(dataTable: {
   hashes: () => {property: string, value: any}[]
}) {
  jMeterConfigPage.updateProperties(dataTable.hashes());
});

When("configure following amazon clusters", function(dataTable: {
  hashes: () => { region: string; maxThreadsPerAgent: number }[];
}) {
  if (amazonConfig.chooseAWS()) {
    const clusters = dataTable.hashes();
    for (const cluster of clusters) {
      amazonConfig.createCluster(cluster);
    }
  }

  amazonConfig.proceedToNextStep();
});

When("finalize the configuration", function() {
  wizardReview.finalize();
});

When("start load generation", function() {
  projectWorkspace.startTest();
});

Then("{int} test should be running", function(numRows) {
  projectWorkspace.waitForTestsToStart(numRows);
  expect(projectWorkspace.isStopEnabled()).to.not.be.true;
});

Given("a test is running", function () {
  expect(projectWorkspace.isTestRunning()).to.be.true;
});

When("I wait for load generation to stop", function () {
  projectWorkspace.waitForTestsToStop();
});

Then("{int} tests should exist", function (numRows) {
  const count = projectWorkspace.waitForFinishedTests(numRows);
  expect(count).to.equal(numRows);
});

When("I reconfigure the project", function () {
  projectWorkspace.reconfigure();
});

When("abort the load generation after {int} seconds", function(timeout) {
  projectWorkspace.abortAfter({seconds: timeout});
});

When("wait for tests to abort", function() {
  projectWorkspace.waitForTestsToStop();
});

When("I terminate the setup", function() {
  this.projectId = projectWorkspace.terminateProject();
});

Given("some tests have completed", function() {
  expect(projectWorkspace.containsStoppedTests()).to.be.true;
});

When("I generate a report", function() {
  projectWorkspace.generateReport();
});

Then("a report file should be created", function() {
  const count = projectWorkspace.waitForGeneratedReports();
  expect(count).to.be.greaterThan(0);
});
