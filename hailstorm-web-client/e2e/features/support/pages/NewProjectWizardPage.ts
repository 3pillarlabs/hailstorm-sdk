import { WizardBase } from './WizardBase';

export class NewProjectWizardPage extends WizardBase {

  get newProjectLink() { return $('*=New Project'); }
  get titleInput() { return $('//input[@name="title"]'); }
  get saveAndNextStep() { return $('button*=Save & Next'); }

  proceedToNextStep(element: WebdriverIO.Element) {
    element.click();
    this.nextLink.waitForEnabled();
    this.nextLink.click();
  }

  createNewProject({ title }: { title: string; }) {
    if (this.newProjectLink.isExisting() && this.newProjectLink.isEnabled()) {
      this.newProjectLink.click();
    }

    this.titleInput.waitForDisplayed(1000);
    this.titleInput.addValue(title);
    this.saveAndNextStep.waitForEnabled(1000);
    this.saveAndNextStep.click();
  }
}
