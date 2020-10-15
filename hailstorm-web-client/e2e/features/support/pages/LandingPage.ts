export class LandingPage {

  open() {
    browser.setTimeout({ implicit: 5000 });
    browser.url('/');
    browser.pause(5000);
  }

  getTitle(): string {
    return browser.getTitle();
  }

  findProjectElement({ title }: { title: string; }): WebdriverIO.Element | undefined {
    browser.pause(3000);
    browser.waitUntil(() => browser.react$('Loader').isDisplayed() === false, 10000);
    const matches = $$(`*=${title}`);
    return matches.length > 0 ? matches[0] : undefined;
  }

  openProject({ title }: { title: string; }) {
    const projectElement = this.findProjectElement({ title });
    projectElement.click();
  }
}
