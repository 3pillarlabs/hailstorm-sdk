
export class ReportWidget {

  get masterCheckBox() { return $('//table/thead/tr/th/input'); }
  get reportButton() { return $('button*=Report'); }
  get reportsListItems() { return $$('//*[@data-testid="Reports List"]/a'); }

  generateReport() {
    browser.pause(500);
    this.masterCheckBox.click();
    this.reportButton.waitForEnabled(5000);
    this.reportButton.click();
  }

  waitForGeneratedReports() {
    browser.waitUntil(() => this.reportsListItems.length > 0, 5 * 60 * 1000, "waiting for report to be generated", 10000);
    return this.reportsListItems.length;
  }
}
