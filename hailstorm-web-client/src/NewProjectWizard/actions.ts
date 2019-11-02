import { Action } from "../store";
import { Project, JMeter } from "../domain";
import { WizardTabTypes } from "./domain";

export enum NewProjectWizardActionTypes {
  ProjectSetup = '[NewProjectWizard] ProjectSetup',
  ProjectSetupCancel = '[NewProjectWizard] ProjectSetupCancel',
  ActivateTab = '[NewProjectWizard] ActivateTab',
  CreateProject = '[NewProjectWizard] CreateProject',
  JMeterSetupCompleted = '[NewProjectWizard] JMeterSetupCompleted',
  ClusterSetupCompleted = '[NewProjectWizard] ClusterSetupCompleted',
  ReviewCompleted = '[NewProjectWizard] ReviewCompleted',
  ConfirmProjectSetupCancel = '[NewProjectWizard] ConfirmProjectSetupCancel',
  StayInProjectSetup = '[NewProjectWizard] StayInProjectSetup',
  UpdateProjectTitle = '[NewProjectWizard] UpdateProjectTitle',
  EditInProjectWizard = '[NewProjectWizard] EditInProjectWizard',
  UnsetProject = '[ProjectWorkspace] UnsetProject',
}

export class ProjectSetupAction implements Action {
  readonly type = NewProjectWizardActionTypes.ProjectSetup;
}

export class ProjectSetupCancelAction implements Action {
  readonly type = NewProjectWizardActionTypes.ProjectSetupCancel;
}

export class ActivateTabAction implements Action {
  readonly type = NewProjectWizardActionTypes.ActivateTab;
  constructor(public payload: WizardTabTypes) {}
}

export class CreateProjectAction implements Action {
  readonly type = NewProjectWizardActionTypes.CreateProject;
  constructor(public payload: Project) {}
}

export class JMeterSetupCompletedAction implements Action {
  readonly type = NewProjectWizardActionTypes.JMeterSetupCompleted;
}

export class ClusterSetupCompletedAction implements Action {
  readonly type = NewProjectWizardActionTypes.ClusterSetupCompleted;
}

export class ReviewCompletedAction implements Action {
  readonly type = NewProjectWizardActionTypes.ReviewCompleted;
}

export class ConfirmProjectSetupCancelAction implements Action {
  readonly type = NewProjectWizardActionTypes.ConfirmProjectSetupCancel;
}

export class StayInProjectSetupAction implements Action {
  readonly type = NewProjectWizardActionTypes.StayInProjectSetup;
}

export class UpdateProjectTitleAction implements Action {
  readonly type = NewProjectWizardActionTypes.UpdateProjectTitle;
  constructor(public payload: string) {}
}

export class EditInProjectWizard implements Action {
  readonly type = NewProjectWizardActionTypes.EditInProjectWizard;
  constructor(public payload: {project: Project, activeTab?: WizardTabTypes}) {}
}

export class UnsetProjectAction implements Action {
  readonly type = NewProjectWizardActionTypes.UnsetProject;
}

export type NewProjectWizardActions =
  | ProjectSetupAction
  | ProjectSetupCancelAction
  | ActivateTabAction
  | CreateProjectAction
  | JMeterSetupCompletedAction
  | ClusterSetupCompletedAction
  | ReviewCompletedAction
  | ConfirmProjectSetupCancelAction
  | StayInProjectSetupAction
  | UpdateProjectTitleAction
  | EditInProjectWizard
  | UnsetProjectAction;
