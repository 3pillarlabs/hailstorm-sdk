import { Action } from '../store';
import { JMeter, ValidationNotice, JMeterFile } from '../domain';
import { JMeterFileUploadState } from '../NewProjectWizard/domain';

export enum JMeterConfigurationActionTypes {
  SetDefaultJMeterVersion = '[JMeterConfiguration] SetDefaultJMeterVersion',
  SetJMeterConfiguration = '[JMeterConfiguration] SetJMeterConfiguration',
  AddJMeterFile = '[JMeterConfiguration] AddJMeterFile',
  CommitJMeterFile = '[JMeterConfiguration] CommitJMeterFile',
  AbortJMeterFileUpload = '[JMeterConfiguration] AbortJMeterFileUpload',
  MergeJMeterFileUpload = '[JMeterConfiguration] MergeJMeterFileUpload',
}

export class SetDefaultJMeterVersionAction implements Action {
  readonly type = JMeterConfigurationActionTypes.SetDefaultJMeterVersion;
  constructor(public payload: string) {}
}

export class SetJMeterConfigurationAction implements Action {
  readonly type = JMeterConfigurationActionTypes.SetJMeterConfiguration;
  constructor(public payload: JMeter) {}
}

export class AddJMeterFileAction implements Action {
  readonly type = JMeterConfigurationActionTypes.AddJMeterFile;
  constructor(public payload: JMeterFileUploadState) {}
}

export class CommitJMeterFileAction implements Action {
  readonly type = JMeterConfigurationActionTypes.CommitJMeterFile;
  constructor(public payload: JMeterFileUploadState) {}
}

export class AbortJMeterFileUploadAction implements Action {
  readonly type = JMeterConfigurationActionTypes.AbortJMeterFileUpload;
  constructor(public payload: JMeterFileUploadState) {}
}

export class MergeJMeterFileAction implements Action {
  readonly type = JMeterConfigurationActionTypes.MergeJMeterFileUpload;
  constructor(public payload: JMeterFile) {}
}

export type JMeterConfigurationActions =
  | SetDefaultJMeterVersionAction
  | SetJMeterConfigurationAction
  | AddJMeterFileAction
  | CommitJMeterFileAction
  | AbortJMeterFileUploadAction
  | MergeJMeterFileAction;
