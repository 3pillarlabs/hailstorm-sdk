import { WizardBase } from './WizardBase';

export class WizardReview extends WizardBase {

  get doneButton() { return $("button*=Done"); }

  finalize() {
    browser.waitUntil(() => this.doneButton.isExisting(), 20000);
    this.doneButton.click();
  }
}
