import * as path from 'path';
import { ClusterConfig } from './ClusterConfig';

export class DataCenterConfig extends ClusterConfig {
  get dcLink() { return $('=Data Center'); }
  get title() { return $('//input[@name="title"]'); }
  get userName() { return $('//input[@name="userName"]'); }
  get fileUpload() { return $('//input[@type="file"]'); }
  get submitBtn() { return $('button*=Save'); }

  machineInput(index: number) {
    return $(`(//div[@data-testid="MachineSet"]//input)[${index + 1}]`);
  }

  choose() {
    return this.chooseCluster(this.dcLink);
  }

  proceedToNextStep() {
    browser.waitUntil(() => this.nextButton.isEnabled(), 15000);
    this.nextButton.click();
  }

  createCluster({
    title,
    userName,
    sshIdentity,
    machines
  }: {
    title: string;
    userName: string;
    sshIdentity: string;
    machines: string;
  }) {
    this.title.setValue(title);
    browser.pause(250);

    this.userName.setValue(userName);
    browser.pause(250);

    this.uploadFile(sshIdentity);
    browser.pause(250);

    machines.split(',').forEach((host, index) => {
      this.machineInput(index).setValue(host);
      browser.pause(250);
    });

    this.submitBtn.waitForEnabled(15000);
    this.submitBtn.click();
  }

  private uploadFile(sshIdentity: string) {
    browser.execute(() => document
      .querySelector('[role="File Upload"]')
      .setAttribute("style", "display: block"));
    const filePath = path.resolve("data", `${sshIdentity}.pem`);
    const remoteFilePath = browser.uploadFile(filePath);
    this.fileUpload.setValue(remoteFilePath);
  }
}
