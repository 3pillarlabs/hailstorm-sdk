
export class TerminateWidget {

  get showDangerousSettings() { return $('button*=Show them'); }
  get terminateButton() { return $('button*=Terminate this project'); }
  get confirmTerminate() { return $('button*=Yes, Terminate'); }
  get notifications() { return $$('button[class=delete][title=Close]') }

  terminateProject() {
    this.notifications.forEach((element) => element.click());
    this.showDangerousSettings.click();
    this.terminateButton.waitForDisplayed(1000);
    this.terminateButton.click();
    this.confirmTerminate.waitForDisplayed(1000);
    this.confirmTerminate.click();
    if (!this.terminateButton.isEnabled()) {
      this.terminateButton.waitForEnabled(1000, true);
      browser.waitUntil(() => this.terminateButton.isEnabled(), 5 * 60 * 1000, "wait for terminate action to complete", 3000);
    }
  }
}
