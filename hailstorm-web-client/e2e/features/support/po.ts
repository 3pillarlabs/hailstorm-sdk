import * as path from 'path';
import * as yaml from 'yaml';
import * as fs from 'fs';
import { readServerIP } from './aws-helper';

class LandingPage {

  open() {
    browser.setTimeout({implicit: 5000});
    browser.url('/');
    browser.pause(5000);
  }

  getTitle(): string {
    return browser.getTitle();
  }

  findProjectElement({title}: {title: string}): WebdriverIO.Element | undefined {
    browser.pause(3000);
    browser.waitUntil(() => browser.react$('Loader').isDisplayed() === false, 10000);
    const matches = $$(`*=${title}`);
    return matches.length > 0 ? matches[0] : undefined;
  }
}

class WizardBase {
  get nextLink() { return $('=Next') }
  get nextButton() { return $('button*=Next') }
}

class NewProjectWizardPage extends WizardBase {

  get newProjectLink() { return $('*=New Project') }
  get titleInput() { return $('//input[@name="title"]') }
  get saveAndNextStep() { return $('button*=Save & Next') }

  proceedToNextStep(element: WebdriverIO.Element) {
    element.click();
    this.nextLink.waitForEnabled();
    this.nextLink.click();
  }

  createNewProject({title}: {title: string}) {
    if (this.newProjectLink.isExisting() && this.newProjectLink.isEnabled()) {
      this.newProjectLink.click();
    }

    this.titleInput.waitForDisplayed(1000);
    this.titleInput.addValue(title);
    this.saveAndNextStep.waitForEnabled(1000);
    this.saveAndNextStep.click();
  }
}

class JMeterConfigPage extends WizardBase {

  get fileUpload() { return $('//input[@type="file"]') }
  get serverNameInput() { return $('//form//input[@name="ServerName"]') }
  get removeButton() { return $('button=Remove') }
  get saveButton() { return $('button*=Save') }

  updateProperties(properties: {property: string, value: any}[]) {
    browser.waitUntil(() => this.fileUpload.isExisting(), 15000);
    if (! this.serverNameInput.isExisting()) {
      this.uploadFile();
    }

    this.fillProperties(properties);
    browser.waitUntil(() => this.saveButton.isEnabled(), 10000);
    this.saveButton.click();
    browser.waitUntil(() => this.nextButton.isEnabled(), 10000);
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
    browser.waitUntil(() => this.removeButton.isDisplayed(), 20000);
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
    browser.waitUntil(() => browser.react$("Loader").isDisplayed() === false, 10000);
    if (this.awsLink.isDisplayed()) {
      this.awsLink.click();
      return true;
    }

    return false;
  }

  createCluster({region, maxThreadsPerAgent}: {region: string, maxThreadsPerAgent: number}) {
    browser.waitUntil(() => this.editRegion.isDisplayed(), 10000);
    const awsCredentials: { accessKey: string; secretKey: string } = yaml.parse(
      fs.readFileSync(path.resolve("data/keys.yml"), "utf8")
    );

    this.accessKey.setValue(awsCredentials.accessKey);
    browser.pause(250);
    this.secretKey.setValue(awsCredentials.secretKey);
    browser.pause(250);
    if (maxThreadsPerAgent) {
      this.advancedMode.click();
      browser.waitUntil(() => this.maxThreadsPerInstance.isExisting());
      this.maxThreadsPerInstance.setValue(maxThreadsPerAgent);
      browser.pause(250);
    }

    this.selectRegion(region);
    const submitBtn = $('button*=Save');
    submitBtn.waitForEnabled(15000);
    submitBtn.click();
  }

  private selectRegion(region: string) {
    const [levelOneRegion, levelTwoRegion] = region.split('/');
    this.editRegion.click();
    browser.pause(500);
    const levelOne = this.regionOptions.find((opt) => opt.getText() === levelOneRegion);
    levelOne.click();
    browser.pause(500);
    const levelTwo = this.regionOptions.find((opt) => opt.getText() === levelTwoRegion);
    levelTwo.click();
    browser.waitUntil(() => $(`//input[@value="${levelTwoRegion}"]`).isExisting(), 10000);
  }

  proceedToNextStep() {
    browser.waitUntil(() => this.nextButton.isEnabled(), 15000);
    this.nextButton.click();
  }
}

class WizardReview extends WizardBase {

  get doneButton() { return $("button*=Done") }

  finalize() {
    browser.waitUntil(() => this.doneButton.isExisting(), 20000);
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
    browser.waitUntil(() => this.startButton.isEnabled(), 15000);
    this.startButton.click();
  }

  isTestRunning() {
    return $$('tr.notification').length > 0;
  }

  waitForTestsToStart(numTests: number) {
    console.info("Tests starting...");
    browser.waitUntil(() => {
      console.info("Waiting for tests to start...");
      return ($$('tr.notification').length === numTests);
    }, 30 * 60 * 1000, "waiting for test to start", 3000);
  }

  isStopEnabled() {
    return this.stopButton.isEnabled();
  }

  waitForTestsToStop() {
    console.info("Tests started successfully, waiting for stop...");
    browser.waitUntil(() => {
      console.info("...waiting for current test to stop");
      return this.startButton.isEnabled();
    }, 15 * 60 * 1000, "waiting for test to stop", 3000);
  }

  waitForFinishedTests(numTests: number): number {
    browser.waitUntil(() => this.checkBoxes.length === numTests, 60 * 1000, "waiting for test to finish", 3000);
    return this.checkBoxes.length;
  }

  containsStoppedTests() {
    return this.checkBoxes.length > 0;
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

  terminateProject() {
    this.showDangerousSettings.click();
    this.terminateButton.waitForDisplayed(1000);
    this.terminateButton.click();
    this.confirmTerminate.waitForDisplayed(1000);
    this.confirmTerminate.click();
    this.terminateButton.waitForEnabled(1000, true);
    browser.waitUntil(() => this.terminateButton.isEnabled(), 5 * 60 * 1000, "wait for terminate action to complete", 3000);
  }

  generateReport() {
    this.masterCheckBox.click();
    this.reportButton.waitForEnabled(1000);
    this.reportButton.click();
  }

  waitForGeneratedReports() {
    browser.waitUntil(() => this.reportsListItems.length > 0, 5 * 60 * 1000, "waiting for report to be generated", 10000);
    return this.reportsListItems.length;
  }

  projectIdFromUrl(): string {
    return path.basename((new URL(browser.getUrl())).hash.slice(1));
  }
}

const landingPage = new LandingPage();
const newProjectWizardPage = new NewProjectWizardPage();
const jMeterConfigPage = new JMeterConfigPage();
const amazonConfig = new AmazonConfig();
const wizardReview = new WizardReview();
const projectWorkspace = new ProjectWorkspace();

export { landingPage, newProjectWizardPage, jMeterConfigPage, amazonConfig, wizardReview, projectWorkspace }
