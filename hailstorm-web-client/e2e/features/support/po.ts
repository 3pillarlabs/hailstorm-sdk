import { LandingPage } from './pages/LandingPage';
import { NewProjectWizardPage } from './pages/NewProjectWizardPage';
import { JMeterConfigPage } from './pages/JMeterConfigPage';
import { AmazonConfig } from './pages/AmazonConfig';
import { WizardReview } from './pages/WizardReview';
import { ProjectWorkspace } from './pages/ProjectWorkspace';
import { ReportWidget } from "./pages/ReportWidget";
import { TerminateWidget } from "./pages/TerminateWidget";
import { DataCenterConfig } from './pages/DataCenterConfig';

const landingPage = new LandingPage();
const newProjectWizardPage = new NewProjectWizardPage();
const jMeterConfigPage = new JMeterConfigPage();
const amazonConfig = new AmazonConfig();
const wizardReview = new WizardReview();
const projectWorkspace = new ProjectWorkspace();
const dataCenterConfig = new DataCenterConfig();
const terminateWidget = new TerminateWidget();
const reportWidget = new ReportWidget();

export {
  landingPage,
  newProjectWizardPage,
  jMeterConfigPage,
  amazonConfig,
  wizardReview,
  projectWorkspace,
  dataCenterConfig,
  terminateWidget,
  reportWidget
}
