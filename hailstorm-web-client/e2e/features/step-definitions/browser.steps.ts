import { Given, When, Then } from "cucumber";
import { expect } from 'chai';
import * as path from 'path';
import { readServerIP } from "features/support/aws-helper";

Given("I have Hailstorm open", function() {
  browser.url('/');
  const title = browser.getTitle();
  expect(title).to.match(/hailstorm/i);
});

Given("I created the project {string}", function(projectTitle: string) {
  browser.waitUntil(() => browser.react$('Loader').isDisplayed() === false);
  const cards = $$(`*=${projectTitle}`);
  if (cards.length === 1) {
    cards[0].click();
    const next = $('=Next');
    next.waitForDisplayed();
    next.click();
  } else {
    const link = $('*=New Project');
    link.click();
    const input = $('//input[@name="title"]');
    input.waitForDisplayed();
    input.addValue(projectTitle);
    const submit = $('//button[@type="submit"]');
    submit.waitForEnabled();
    submit.click();
  }
});

 When("I configure JMeter with following properties", function(dataTable: {
   hashes: () => {property: string, value: any}[]
}) {
  browser.waitUntil(() => $('//input[@type="file"]').isExisting());
  if (! $(`//form//input[@name="ServerName"]`).isExisting()) {
    browser.execute(() =>
      document
        .querySelector('[role="File Upload"]')
        .setAttribute("style", "display: block")
    );

    const filePath = path.resolve("data", "hailstorm-site-basic.jmx");
    const remoteFilePath = browser.uploadFile(filePath);
    $('//input[@type="file"]').setValue(remoteFilePath);
    browser.waitUntil(
      () => $('//button[@role="Remove File"]').isDisplayed(),
      15000
    );
  }

  const jmeterProperties = dataTable.hashes();
  jmeterProperties.push({ property: "ServerName", value: readServerIP() });
  jmeterProperties.forEach(({ property, value }) => {
    $(`//form//input[@name="${property}"]`).setValue(value);
  });

  $('//form//button[@type="submit"]').click();
  browser.waitUntil(() => $('//form//button[@type="submit"]').isEnabled());
  $('button.is-primary').click();
 });

 When("configure following amazon clusters", function(dataTable) {
   // Write code here that turns the phrase above into concrete actions
   return "pending";
 });

 When("finalize the configuration", function() {
   // Write code here that turns the phrase above into concrete actions
   return "pending";
});

When("start load generation", function() {
  // Write code here that turns the phrase above into concrete actions
  return "pending";
});

Then("{int} test should be running", function(int) {
  // Write code here that turns the phrase above into concrete actions
  return "pending";
});

When("wait for {int} seconds", function(int) {
  // Write code here that turns the phrase above into concrete actions
  return "pending";
});

When("abort the load generation", function() {
  // Write code here that turns the phrase above into concrete actions
  return "pending";
});

When("I terminate the setup", function() {
  // Write code here that turns the phrase above into concrete actions
  return "pending";
});

When("I generate a report", function() {
  // Write code here that turns the phrase above into concrete actions
  return "pending";
});

Then("a report file should be created", function() {
  // Write code here that turns the phrase above into concrete actions
  return "pending";
});
