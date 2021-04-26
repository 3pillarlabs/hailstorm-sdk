import {
  JMeterConfigurationActions,
  JMeterConfigurationActionTypes,
  CommitJMeterFileAction,
  AbortJMeterFileUploadAction,
  AddJMeterFileAction,
  MergeJMeterFileAction,
  SetJMeterConfigurationAction,
  RemoveJMeterFileAction,
  FileRemoveInProgressAction
} from "./actions";
import { NewProjectWizardState, NewProjectWizardProgress, JMeterFileUploadState, WizardTabTypes } from "../NewProjectWizard/domain";
import { Project, JMeterFile } from "../domain";

export function reducer(state: NewProjectWizardState, action: JMeterConfigurationActions): NewProjectWizardState {
  let nextState: NewProjectWizardState;
  switch (action.type) {
    case JMeterConfigurationActionTypes.AddJMeterFile:
      nextState = onAddJMeterFile(state, action);
      break;

    case JMeterConfigurationActionTypes.AbortJMeterFileUpload:
      nextState = onAbortJMeterFileUpload(state, action);
      break;

    case JMeterConfigurationActionTypes.CommitJMeterFile:
      nextState = onCommitJMeterFile(state, action);
      break;

    case JMeterConfigurationActionTypes.MergeJMeterFileUpload:
      nextState = onMergeJMeterFileUpload(state, action);
      break;

    case JMeterConfigurationActionTypes.SetJMeterConfiguration:
      nextState = onSetJMeterConfiguration(state, action);
      break;

    case JMeterConfigurationActionTypes.SelectJMeterFile: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeJMeterFile: action.payload};
      nextState = {...state, wizardState};
      break;
    }

    case JMeterConfigurationActionTypes.RemoveJMeterFile:
      nextState = onRemoveJMeterFile(state, action);
      break;

    case JMeterConfigurationActionTypes.FileRemoveInProgress:
      nextState = onFileRemoveInProgress(state, action);
      break;

    case JMeterConfigurationActionTypes.DisableJMeterFile:
      nextState = onChangeJMeterFileDisability(state, {id: action.payload, disabled: true});
      break;

    case JMeterConfigurationActionTypes.EnableJMeterFile:
      nextState = onChangeJMeterFileDisability(state, {id: action.payload, disabled: false});
      break;

    default:
      nextState = state;
      break;
  }

  return nextState;
}

function onFileRemoveInProgress(state: NewProjectWizardState, action: FileRemoveInProgressAction) {
  const wizardState = { ...state.wizardState! };
  if (wizardState.activeJMeterFile) {
    wizardState.activeJMeterFile = { ...wizardState.activeJMeterFile, removeInProgress: action.payload };
  }
  return { ...state, wizardState };
}

function onRemoveJMeterFile(state: NewProjectWizardState, action: RemoveJMeterFileAction) {
  const activeProject = { ...state.activeProject! };
  if (activeProject.jmeter) {
    activeProject.jmeter.files = activeProject.jmeter.files.filter((value) => value.id !== action.payload.id);
    if (activeProject.jmeter.files.some((value) => !value.dataFile) === false) {
      activeProject.incomplete = true;
    }
  }
  const wizardState = { ...state.wizardState! };
  if (activeProject.jmeter && activeProject.jmeter.files.length > 0) {
    wizardState.activeJMeterFile = activeProject.jmeter!.files[0];
  }
  else {
    wizardState.activeJMeterFile = undefined;
  }
  if (wizardState.done[WizardTabTypes.Review]) {
    wizardState.modifiedAfterReview = true;
  }
  return { ...state, activeProject, wizardState };
}

function onSetJMeterConfiguration(state: NewProjectWizardState, action: SetJMeterConfigurationAction) {
  const activeProject: Project = {...state.activeProject!};
  activeProject.jmeter = {...action.payload};
  activeProject.jmeter.files = action.payload.files.sort(jmeterFileCompare);
  if (state.wizardState && state.wizardState.activeTab === WizardTabTypes.JMeter &&
      activeProject.jmeter.files.length > 0 && !state.wizardState.activeJMeterFile
  ) {
      const wizardState = {...state.wizardState};
      wizardState.activeJMeterFile = activeProject.jmeter.files[0];
      return {...state, activeProject, wizardState};
  }

  return {...state, activeProject};
}

function onMergeJMeterFileUpload(state: NewProjectWizardState, action: MergeJMeterFileAction) {
  const activeProject: Project = { ...state.activeProject! };
  if (!activeProject.jmeter) {
    activeProject.jmeter = {
      files: []
    };
  }
  if (state.wizardState!.activeJMeterFile!.id === undefined) {
    activeProject.jmeter.files = [...activeProject.jmeter.files, action.payload].sort(jmeterFileCompare);
  }
  else {
    activeProject.jmeter.files = [...activeProject.jmeter.files];
    const jmeterFile = activeProject.jmeter.files.find((value) => value.id === action.payload.id);
    if (jmeterFile) {
      jmeterFile.properties = action.payload.properties;
    }
  }
  const activeJMeterFile: JMeterFileUploadState = {
    ...state.wizardState!.activeJMeterFile!,
    properties: action.payload.properties,
    id: action.payload.id
  };
  const wizardState: NewProjectWizardProgress = {
    ...state.wizardState!,
    activeJMeterFile
  };
  if (wizardState.done[WizardTabTypes.Review]) {
    wizardState.modifiedAfterReview = true;
  }
  return { ...state, wizardState, activeProject };
}

function onCommitJMeterFile(state: NewProjectWizardState, action: CommitJMeterFileAction) {
  const activeJMeterFile: JMeterFileUploadState = {
    ...state.wizardState!.activeJMeterFile!,
    uploadProgress: 100,
    properties: action.payload.properties
  };
  if (action.payload.path) {
    activeJMeterFile.path = action.payload.path;
  }
  const wizardState: NewProjectWizardProgress = {
    ...state.wizardState!,
    activeJMeterFile
  };
  const activeProject = { ...state.activeProject! };
  if (action.payload.autoStop !== undefined && activeProject.autoStop !== false) {
    activeProject.autoStop = action.payload.autoStop;
  }

  return { ...state, wizardState, activeProject };
}

function onAbortJMeterFileUpload(state: NewProjectWizardState, action: AbortJMeterFileUploadAction) {
  const activeJMeterFile: JMeterFileUploadState = { ...state.wizardState!.activeJMeterFile! };
  if (action.payload.uploadError) {
    activeJMeterFile.uploadError = action.payload.uploadError;
    activeJMeterFile.uploadProgress = undefined;
  }
  else if (action.payload.validationErrors) {
    activeJMeterFile.validationErrors = action.payload.validationErrors;
    activeJMeterFile.uploadProgress = 100;
  }
  const wizardState: NewProjectWizardProgress = {
    ...state.wizardState!,
    activeJMeterFile
  };
  return { ...state, wizardState };
}

function onAddJMeterFile(state: NewProjectWizardState, action: AddJMeterFileAction) {
  const wizardProgress: NewProjectWizardProgress = { ...state.wizardState! };
  wizardProgress.activeJMeterFile = { ...action.payload, uploadProgress: 0, uploadError: undefined };
  const nextState: NewProjectWizardState = { ...state };
  nextState.wizardState = wizardProgress;
  return nextState;
}

function jmeterFileCompare(a: JMeterFile, b: JMeterFile): number {
  let scoreA = 0, scoreB = 0;

  if (a.disabled)
    ++scoreA;
  if (a.dataFile)
    ++scoreA;
  if (b.disabled)
    ++scoreB;
  if (b.dataFile)
    ++scoreB;

  return (scoreA - scoreB);
}

function onChangeJMeterFileDisability(
  state: NewProjectWizardState, {
    id,
    disabled
  }: {
    id: number,
    disabled: boolean
  }): NewProjectWizardState {

    const activeProject = {...state.activeProject!};
    const wizardState = {...state.wizardState!};
    const disableJMeterPlan: (plan: JMeterFile, disabled: boolean) => JMeterFile = (plan, disabled) => {
      if (disabled === true) {
        return {...plan, disabled};
      } else {
        const vNext = {...plan};
        delete vNext.disabled;
        return vNext;
      }
    };

    activeProject.jmeter!.files = activeProject.jmeter!.files.map((v) => {
      if (v.id === id) {
        return disableJMeterPlan(v, disabled);
      }

      return v;
    });

    wizardState.activeJMeterFile = disableJMeterPlan(wizardState.activeJMeterFile!, disabled);
    if (activeProject.jmeter!.files.filter((v) => !v.dataFile).every((v) => v.disabled)) {
      activeProject.incomplete = true;
    }

    if (wizardState.done[WizardTabTypes.Review]) {
      wizardState.modifiedAfterReview = true;
    }

    return {...state, activeProject, wizardState};
}
