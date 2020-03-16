import { expect } from 'chai';
import * as path from 'path';
import * as yaml from 'yaml';
import * as fs from 'fs';
import axios from 'axios';
import { readServerIP } from './aws-helper';
import config from 'environment.e2e';

class LandingPage {

  open() {
    browser.setTimeout({pageLoad: 3600000});
    browser.setTimeout({script: 3600000});
    browser.url('/');
  }

  getTitle(): string {
    return browser.getTitle();
  }

  findProjectElement({title}: {title: string}): WebdriverIO.Element | undefined {
    browser.waitUntil(() => browser.react$('Loader').isDisplayed() === false);
    const matches = $$(`*=${title}`);
    return matches.length > 0 ? matches[0] : undefined;
  }
}

class WizardBase {
  get nextLink() { return $('=Next') }
  get nextButton() { return $('button=Next') }
}

class NewProjectWizardPage extends WizardBase {

  get newProjectLink() { return $('*=New Project') }
  get titleInput() { return $('//input[@name="title"]') }
  get saveAndNextStep() { return $('button*=Save & Next') }

  proceedToNextStep(element: WebdriverIO.Element) {
    element.click();
    this.nextLink.waitForDisplayed();
    this.nextLink.click();
  }

  createNewProject({title}: {title: string}) {
    if (this.newProjectLink.isExisting()) {
      this.newProjectLink.click();
    }

    this.titleInput.waitForDisplayed();
    this.titleInput.addValue(title);
    this.saveAndNextStep.waitForEnabled();
    this.saveAndNextStep.click();
  }
}

class JMeterConfigPage extends WizardBase {

  get fileUpload() { return $('//input[@type="file"]') }
  get serverNameInput() { return $('//form//input[@name="ServerName"]') }
  get removeButton() { return $('button=Remove') }
  get saveButton() { return $('button*=Save') }

  updateProperties(properties: {property: string, value: any}[]) {
    browser.waitUntil(() => this.fileUpload.isExisting());
    if (! this.serverNameInput.isExisting()) {
      this.uploadFile();
    }

    this.fillProperties(properties);
    this.saveButton.click();
    browser.waitUntil(() => this.saveButton.isEnabled());
    this.nextButton.click();
  }

  private fillProperties(properties: { property: string; value: any; }[]) {
    properties.push({ property: "ServerName", value: readServerIP() });
    properties.forEach(({ property, value }) => {
      $(`//form//input[@name="${property}"]`).setValue(value);
    });
  }

  private uploadFile() {
    browser.execute(() => document
      .querySelector('[role="File Upload"]')
      .setAttribute("style", "display: block"));
    const filePath = path.resolve("data", "hailstorm-site-basic.jmx");
    const remoteFilePath = browser.uploadFile(filePath);
    this.fileUpload.setValue(remoteFilePath);
    browser.waitUntil(() => this.removeButton.isDisplayed(), 15000);
  }
}

class AmazonConfig extends WizardBase {

  get awsLink() { return $('=AWS') }
  get editRegion() { return $('//a[@role="EditRegion"]') }
  get accessKey() { return $('//input[@name="accessKey"]') }
  get secretKey() { return $('//input[@name="secretKey"]') }
  get regionOptions() { return $$('//a[@role="AWSRegionOption"]') }
  get advancedMode() { return $('=Advanced Mode') }
  get maxThreadsPerInstance() { return $('//input[@name="maxThreadsByInstance"]') }

  chooseAWS() {
    browser.waitUntil(() => browser.react$("Loader").isDisplayed() === false);
    if (this.awsLink.isDisplayed()) {
      this.awsLink.click();
      return true;
    }

    return false;
  }

  createCluster({region, maxThreadsPerAgent}: {region: string, maxThreadsPerAgent: number}) {
    browser.waitUntil(() => this.editRegion.isDisplayed());
    const awsCredentials: { accessKey: string; secretKey: string } = yaml.parse(
      fs.readFileSync(path.resolve("data/keys.yml"), "utf8")
    );

    this.accessKey.setValue(awsCredentials.accessKey);
    this.secretKey.setValue(awsCredentials.secretKey);
    if (maxThreadsPerAgent) {
      this.advancedMode.click();
      this.maxThreadsPerInstance.setValue(maxThreadsPerAgent);
    }

    this.selectRegion(region);
    const submitBtn = $('button*=Save');
    submitBtn.click();
  }

  private selectRegion(region: string) {
    const [levelOneRegion, levelTwoRegion] = region.split('/');
    this.editRegion.click();
    const levelOne = this.regionOptions.find((region) => region.getText() === levelOneRegion);
    levelOne.click();
    const levelTwo = this.regionOptions.find((region) => region.getText() === levelTwoRegion);
    levelTwo.click();
    browser.waitUntil(() => $(`//input[@value="${levelTwoRegion}"]`).isExisting());
  }

  proceedToNextStep() {
    browser.waitUntil(() => this.nextButton.isEnabled());
    this.nextButton.click();
  }
}

class WizardReview extends WizardBase {

  get doneButton() { return $("button*=Done") }

  finalize() {
    browser.waitUntil(() => this.doneButton.isExisting());
    this.doneButton.click();
  }
}

class ProjectWorkspace {

  get startButton() { return $('button*=Start') }
  get stopButton() { return $('button*=Stop') }
  get checkBoxes() { return $$('//tbody//tr/td/input') }
  get jMeterPlansEdit() { return $('//*[@data-testid="JMeter Plans"]//button') }
  get abortButton() { return $('button*=Abort') }
  get showDangerousSettings() { return $('button*=Show them') }
  get terminateButton() { return $('button*=Terminate this project') }
  get confirmTerminate() { return $('button*=Yes, Terminate') }
  get masterCheckBox() { return $('//table/thead/tr/th/input') }
  get reportButton() { return $('button*=Report') }
  get reportsListItems() { return $$('//*[@data-testid="Reports List"]/a') }

  startTest() {
    browser.waitUntil(() => this.startButton.isDisplayed());
    this.startButton.click();
  }

  waitForTestsToStart(numTests: number) {
    console.info("Tests starting...");
    browser.waitUntil(() => $$('tr.notification').length === numTests, 30 * 60 * 1000, "waiting for test to start");
  }

  isStopEnabled() {
    return this.stopButton.isEnabled();
  }

  waitForTestsToStop() {
    console.info("Tests started successfully, waiting for stop...");
    browser.waitUntil(() => this.startButton.isEnabled(), 15 * 60 * 1000, "waiting for test to stop");
  }

  waitForFinishedTests(numTests: number): number {
    browser.waitUntil(() => this.checkBoxes.length === numTests, 60 * 1000);
    return this.checkBoxes.length;
  }

  reconfigure() {
    this.jMeterPlansEdit.click();
  }

  abortAfter({seconds}: {seconds: number}) {
    const abortButton = this.abortButton;
    setTimeout(() => {
      abortButton.click();
    }, seconds * 1000);
  }

  terminateProject(): string {
    this.showDangerousSettings.click();
    this.terminateButton.click();
    this.confirmTerminate.click();
    browser.waitUntil(() => !this.terminateButton.isEnabled());
    browser.waitUntil(() => this.terminateButton.isEnabled(), 5 * 60 * 1000);
    return path.basename((new URL(browser.getUrl())).hash.slice(1));
  }

  generateReport() {
    this.masterCheckBox.click();
    this.reportButton.click();
  }

  waitForGeneratedReports() {
    browser.waitUntil(() => this.reportsListItems.length > 0, 5 * 60 * 1000, "waiting for report to be generated");
    return this.reportsListItems.length;
  }
}

const landingPage = new LandingPage();
const newProjectWizardPage = new NewProjectWizardPage();
const jMeterConfigPage = new JMeterConfigPage();
const amazonConfig = new AmazonConfig();
const wizardReview = new WizardReview();
const projectWorkspace = new ProjectWorkspace();

export { landingPage, newProjectWizardPage, jMeterConfigPage, amazonConfig, wizardReview, projectWorkspace }
