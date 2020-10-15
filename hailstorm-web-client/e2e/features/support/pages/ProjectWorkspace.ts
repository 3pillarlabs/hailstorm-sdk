import * as path from 'path';

export class ProjectWorkspace {

  get startButton() { return $('button*=Start'); }
  get stopButton() { return $('button*=Stop'); }
  get checkBoxes() { return $$('//tbody//tr/td/input'); }
  get jMeterPlansEdit() { return $('//*[@data-testid="JMeter Plans"]//button'); }
  get abortButton() { return $('button*=Abort'); }

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

  waitForFinishedTests(numTests?: number): number {
    const fn = !!numTests ? () => this.checkBoxes.length === numTests! : () => this.checkBoxes.length > 0;
    browser.waitUntil(fn, 60 * 1000, "waiting for test to finish", 3000);
    return this.checkBoxes.length;
  }

  containsStoppedTests() {
    return this.checkBoxes.length > 0;
  }

  reconfigure() {
    this.jMeterPlansEdit.click();
  }

  abortAfter({ seconds }: { seconds: number; }) {
    const abortButton = this.abortButton;
    setTimeout(() => {
      abortButton.click();
    }, seconds * 1000);
  }

  projectIdFromUrl(): string {
    return path.basename((new URL(browser.getUrl())).hash.slice(1));
  }
}
