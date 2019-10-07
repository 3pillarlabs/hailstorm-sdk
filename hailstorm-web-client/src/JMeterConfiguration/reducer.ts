import { JMeterConfigurationActions, JMeterConfigurationActionTypes } from "./actions";
import { NewProjectWizardState, NewProjectWizardProgress, JMeterFileUploadState } from "../NewProjectWizard/domain";
import { Project } from "../domain";

export function reducer(state: NewProjectWizardState, action: JMeterConfigurationActions): NewProjectWizardState {
  switch (action.type) {
    case JMeterConfigurationActionTypes.AddJMeterFile: {
      const wizardProgress: NewProjectWizardProgress =  {...state.wizardState!};
      wizardProgress.activeJMeterFile = {...action.payload};
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

      const wizardState: NewProjectWizardProgress =  {
        ...state.wizardState!,
        activeJMeterFile
      };

      return {...state, wizardState};
    }

    case JMeterConfigurationActionTypes.MergeJMeterFileUpload: {
      const activeProject: Project = {...state.activeProject!};
      if (!activeProject.jmeter) {
        activeProject.jmeter = {
          files: []
        }
      }

      if (state.wizardState!.activeJMeterFile!.id === undefined) {
        activeProject.jmeter.files = [...activeProject.jmeter.files, action.payload];
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

      return {...state, wizardState, activeProject};
    }

    case JMeterConfigurationActionTypes.SetJMeterConfiguration: {
      const activeProject: Project = {...state.activeProject!};
      activeProject.jmeter = {...action.payload};

      return {...state, activeProject};
    }

    default:
      break;
  }

  return state;
}
