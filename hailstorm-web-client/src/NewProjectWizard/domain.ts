import { Project, ValidationNotice, JMeterFile } from "../domain";

export enum WizardTabTypes {
  Project = 'Project',
  JMeter = 'JMeter',
  Cluster = 'Cluster',
  Review = 'Review'
}

type WizardTabTypesStrings = keyof typeof WizardTabTypes;

export interface NewProjectWizardProgress {
  activeTab: WizardTabTypes;
  done: {
    [k in WizardTabTypesStrings]?: boolean;
  };
  confirmCancel?: boolean;
  activeJMeterFile?: JMeterFileUploadState;
}

export interface NewProjectWizardState {
  activeProject: Project | undefined;
  wizardState?: NewProjectWizardProgress;
}

export interface JMeterFileUploadState extends JMeterFile {
  uploadProgress?: number;
  uploadError?: any;
  validationErrors?: ValidationNotice[];
}
