import { WizardBase } from './WizardBase';

export class ClusterConfig extends WizardBase {

  protected chooseCluster(clusterLink: WebdriverIO.Element) {
    browser.waitUntil(() => browser.react$("Loader").isDisplayed() === false, 10000);
    if (clusterLink.isDisplayed()) {
      clusterLink.click();
      return true;
    }

    return false;
  }
}
