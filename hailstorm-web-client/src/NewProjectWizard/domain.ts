import { Project, ValidationNotice, JMeterFile, Cluster } from "../domain";

export enum WizardTabTypes {
  Project = 'Project',
  JMeter = 'JMeter',
  Cluster = 'Cluster',
  Review = 'Review'
}

export interface JMeterFileUploadState extends JMeterFile {
  uploadProgress?: number;
  uploadError?: any;
  validationErrors?: ValidationNotice[];
  removeInProgress?: string;
}

type WizardTabTypesStrings = keyof typeof WizardTabTypes;

export interface NewProjectWizardProgress {
  activeTab: WizardTabTypes;
  done: {
    [k in WizardTabTypesStrings]?: boolean;
  };
  confirmCancel?: boolean;
  activeJMeterFile?: JMeterFileUploadState;
  activeCluster?: Cluster;
  modifiedAfterReview?: boolean;
}


export interface NewProjectWizardState {
  activeProject: Project | undefined;
  wizardState?: NewProjectWizardProgress;
}
