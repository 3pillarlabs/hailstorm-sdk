import { JMeterConfigurationActions, JMeterConfigurationActionTypes } from "./actions";
import { NewProjectWizardState, NewProjectWizardProgress, JMeterFileUploadState, WizardTabTypes } from "../NewProjectWizard/domain";
import { Project, JMeterFile } from "../domain";

export function reducer(state: NewProjectWizardState, action: JMeterConfigurationActions): NewProjectWizardState {
  switch (action.type) {
    case JMeterConfigurationActionTypes.AddJMeterFile: {
      const wizardProgress: NewProjectWizardProgress =  {...state.wizardState!};
      wizardProgress.activeJMeterFile = {...action.payload, uploadProgress: 0, uploadError: undefined};
      const nextState: NewProjectWizardState = {...state};
      nextState.wizardState = wizardProgress;
      return nextState;
    }

    case JMeterConfigurationActionTypes.AbortJMeterFileUpload: {
      const activeJMeterFile:JMeterFileUploadState = { ...state.wizardState!.activeJMeterFile! };

      if (action.payload.uploadError) {
        activeJMeterFile.uploadError = action.payload.uploadError;
        activeJMeterFile.uploadProgress = undefined;
      } else if (action.payload.validationErrors) {
        activeJMeterFile.validationErrors = action.payload.validationErrors;
        activeJMeterFile.uploadProgress = 100;
      }

      const wizardState: NewProjectWizardProgress =  {
        ...state.wizardState!,
        activeJMeterFile
      };

      return {...state, wizardState};
    }

    case JMeterConfigurationActionTypes.CommitJMeterFile: {
      const activeJMeterFile:JMeterFileUploadState = {
        ...state.wizardState!.activeJMeterFile!,
        uploadProgress: 100,
        properties: action.payload.properties
      };

      if (action.payload.path) {
        activeJMeterFile.path = action.payload.path;
      }

      const wizardState: NewProjectWizardProgress =  {
        ...state.wizardState!,
        activeJMeterFile
      };

      const activeProject = {...state.activeProject!};
      if (action.payload.autoStop !== undefined) {
        if (activeProject.autoStop === undefined || activeProject.autoStop) {
          activeProject.autoStop = action.payload.autoStop;
        }
      }

      return {...state, wizardState, activeProject};
    }

    case JMeterConfigurationActionTypes.MergeJMeterFileUpload: {
      const activeProject: Project = {...state.activeProject!};
      if (!activeProject.jmeter) {
        activeProject.jmeter = {
          files: []
        }
      }

      if (state.wizardState!.activeJMeterFile!.id === undefined) {
        activeProject.jmeter.files = [...activeProject.jmeter.files, action.payload].sort(jmeterFileCompare);
      } else {
        activeProject.jmeter.files = [...activeProject.jmeter.files];
        const jmeterFile = activeProject.jmeter.files.find((value) => value.id === action.payload.id);
        if (jmeterFile) {
          jmeterFile.properties = action.payload.properties;
        }
      }

      const activeJMeterFile:JMeterFileUploadState = {
        ...state.wizardState!.activeJMeterFile!,
        properties: action.payload.properties,
        id: action.payload.id
      };

      const wizardState: NewProjectWizardProgress =  {
        ...state.wizardState!,
        activeJMeterFile
      };

      if (wizardState.done[WizardTabTypes.Review]) {
        wizardState.modifiedAfterReview = true;
      }

      return {...state, wizardState, activeProject};
    }

    case JMeterConfigurationActionTypes.SetJMeterConfiguration: {
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

    case JMeterConfigurationActionTypes.SelectJMeterFile: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeJMeterFile: action.payload};
      return {...state, wizardState};
    }

    case JMeterConfigurationActionTypes.RemoveJMeterFile: {
      const activeProject = {...state.activeProject!};
      if (activeProject.jmeter) {
        activeProject.jmeter.files = activeProject.jmeter.files.filter((value) => value.id !== action.payload.id);
        if (activeProject.jmeter.files.some((value) => !value.dataFile) === false) {
          activeProject.incomplete = true;
        }
      }

      const wizardState = {...state.wizardState!};
      if (activeProject.jmeter && activeProject.jmeter.files.length > 0) {
        wizardState.activeJMeterFile = activeProject.jmeter!.files[0];
      } else {
        wizardState.activeJMeterFile = undefined;
      }

      if (wizardState.done[WizardTabTypes.Review]) {
        wizardState.modifiedAfterReview = true;
      }

      return {...state, activeProject, wizardState};
    }

    case JMeterConfigurationActionTypes.FileRemoveInProgress: {
      const wizardState = {...state.wizardState!};
      if (wizardState.activeJMeterFile) {
        wizardState.activeJMeterFile = {...wizardState.activeJMeterFile, removeInProgress: action.payload};
      }

      return {...state, wizardState};
    }

    default:
      break;
  }

  return state;
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
