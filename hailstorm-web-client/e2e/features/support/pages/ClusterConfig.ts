import { WizardBase } from './WizardBase';

export class ClusterConfig extends WizardBase {

  proceedToNextStep() {
    browser.waitUntil(() => this.nextButton.isEnabled(), 15000);
    this.nextButton.click();
  }

  protected chooseCluster(clusterLink: WebdriverIO.Element) {
    browser.waitUntil(() => browser.react$("Loader").isDisplayed() === false, 10000);
    if (clusterLink.isDisplayed()) {
      clusterLink.click();
      return true;
    }

    return false;
  }
}
