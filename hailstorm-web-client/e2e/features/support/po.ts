import { LandingPage } from './pages/LandingPage';
import { NewProjectWizardPage } from './pages/NewProjectWizardPage';
import { JMeterConfigPage } from './pages/JMeterConfigPage';
import { AmazonConfig } from './pages/AmazonConfig';
import { WizardReview } from './pages/WizardReview';
import { ProjectWorkspace } from './pages/ProjectWorkspace';
import { DataCenterConfig } from './DataCenterConfig';

const landingPage = new LandingPage();
const newProjectWizardPage = new NewProjectWizardPage();
const jMeterConfigPage = new JMeterConfigPage();
const amazonConfig = new AmazonConfig();
const wizardReview = new WizardReview();
const projectWorkspace = new ProjectWorkspace();
const dataCenterConfig = new DataCenterConfig();

export {
  landingPage,
  newProjectWizardPage,
  jMeterConfigPage,
  amazonConfig,
  wizardReview,
  projectWorkspace,
  dataCenterConfig
}
