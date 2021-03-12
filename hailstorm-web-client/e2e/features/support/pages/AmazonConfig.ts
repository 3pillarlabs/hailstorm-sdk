import * as path from 'path';
import * as yaml from 'yaml';
import * as fs from 'fs';
import { ClusterConfig } from './ClusterConfig';

export class AmazonConfig extends ClusterConfig {

  get awsLink() { return $('=AWS'); }
  get editRegion() { return $('//a[@role="EditRegion"]'); }
  get accessKey() { return $('//input[@name="accessKey"]'); }
  get secretKey() { return $('//input[@name="secretKey"]'); }
  get regionOptions() { return $$('//a[@role="AWSRegionOption"]'); }
  get advancedMode() { return $('=Advanced Mode'); }
  get maxThreadsPerInstance() { return $('//input[@name="maxThreadsByInstance"]'); }
  get updateButton() { return $('//button[@role="Update Cluster"]'); }

  choose() {
    return this.chooseCluster(this.awsLink);
  }

  createCluster({ region, maxThreadsPerAgent }: { region: string; maxThreadsPerAgent: number | undefined; }) {
    browser.waitUntil(() => this.editRegion.isDisplayed(), 10000);
    const awsCredentials: { accessKey: string; secretKey: string; } = yaml.parse(
      fs.readFileSync(path.resolve("data/keys.yml"), "utf8")
    );

    this.accessKey.setValue(awsCredentials.accessKey);
    browser.pause(250);
    this.secretKey.setValue(awsCredentials.secretKey);
    browser.pause(250);
    this.selectRegion(region);
    if (maxThreadsPerAgent) {
      this.updateCluster({maxThreadsPerAgent});
    }

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

  updateCluster({maxThreadsPerAgent}: {maxThreadsPerAgent: number}) {
    if (this.maxThreadsPerInstance.getValue() !== maxThreadsPerAgent.toString()) {
      this.maxThreadsPerInstance.setValue(maxThreadsPerAgent.toString());
      browser.pause(250);
      browser.waitUntil(() => this.updateButton.isEnabled(), 500);
      this.updateButton.click();
    }
  }
}
