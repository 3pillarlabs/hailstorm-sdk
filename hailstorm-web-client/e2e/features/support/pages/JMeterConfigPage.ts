import * as path from 'path';
import { readServerIP } from '../aws-helper';
import { WizardBase } from './WizardBase';

export class JMeterConfigPage extends WizardBase {

  get fileUpload() { return $('//input[@type="file"]'); }
  get serverNameInput() { return $('//form//input[@name="ServerName"]'); }
  get removeButton() { return $('button=Remove'); }
  get saveButton() { return $('button*=Save'); }

  updateProperties(properties: { property: string; value: any; }[]) {
    browser.waitUntil(() => this.fileUpload.isExisting(), 15000);
    if (!this.serverNameInput.isExisting()) {
      this.uploadFile();
    }

    this.fillProperties(properties);
    browser.waitUntil(() => this.saveButton.isEnabled(), 10000);
    this.saveButton.click();
    browser.waitUntil(() => this.nextButton.isEnabled(), 10000);
    this.nextButton.click();
  }

  private fillProperties(properties: { property: string; value: any; }[]) {
    properties.forEach(({ property, value }) => {
      if (property === "ServerName") {
        value = readServerIP(value);
      }

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
