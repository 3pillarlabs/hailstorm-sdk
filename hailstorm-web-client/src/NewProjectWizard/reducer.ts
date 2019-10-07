import { NewProjectWizardActions, NewProjectWizardActionTypes } from "./actions";
import { NewProjectWizardState, WizardTabTypes, NewProjectWizardProgress } from "./domain";
import { AppState } from "../store";

export function reducer(state: NewProjectWizardState, action: NewProjectWizardActions): NewProjectWizardState {
  switch (action.type) {
    case NewProjectWizardActionTypes.ProjectSetup: {
      const nextState: NewProjectWizardState = {...state, activeProject: undefined};
      return {...nextState, wizardState: {activeTab: WizardTabTypes.Project, done: {}}};
    }

    case NewProjectWizardActionTypes.ProjectSetupCancel: {
      const nextState: NewProjectWizardState = {...state, activeProject: undefined};
      delete nextState.wizardState;
      return nextState;
    }

    case NewProjectWizardActionTypes.ActivateTab: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeTab: action.payload};
      return {...state, wizardState};
    }

    case NewProjectWizardActionTypes.CreateProject: {
      const wizardState: NewProjectWizardProgress = {
        ...state.wizardState!,
        activeTab: WizardTabTypes.JMeter,
        done: {
          ...state.wizardState!.done,
          [WizardTabTypes.Project]: true
        }
      };

      return {...state, wizardState, activeProject: action.payload};
    }

    case NewProjectWizardActionTypes.JMeterSetupCompleted: {
      const wizardState: NewProjectWizardProgress = {
        ...state.wizardState!,
        activeTab: WizardTabTypes.Cluster,
        done: {
          ...state.wizardState!.done,
          [WizardTabTypes.JMeter]: true
        }
      };

      return {...state, wizardState};
    }

    case NewProjectWizardActionTypes.ClusterSetupCompleted: {
      const wizardState: NewProjectWizardProgress = {
        ...state.wizardState!,
        activeTab: WizardTabTypes.Review,
        done: {
          ...state.wizardState!.done,
          [WizardTabTypes.Cluster]: true
        }
      };

      return {...state, wizardState};
    }

    case NewProjectWizardActionTypes.ReviewCompleted: {
      const nextState = {...state};
      delete nextState.wizardState;
      return nextState;
    }

    case NewProjectWizardActionTypes.ConfirmProjectSetupCancel: {
      if (!state.activeProject) {
        const nextState = {...state};
        delete nextState.wizardState;
        return nextState;
      }

      const wizardState: NewProjectWizardProgress = {
        ...state.wizardState!,
        confirmCancel: true
      }

      return {...state, wizardState};
    }

    case NewProjectWizardActionTypes.StayInProjectSetup: {
      const wizardState = {...state.wizardState!}
      delete wizardState.confirmCancel;
      return {...state, wizardState};
    }

    case NewProjectWizardActionTypes.UpdateProjectTitle: {
      const activeProject = {...state.activeProject!, title: action.payload};
      const wizardState: NewProjectWizardProgress = {
        ...state.wizardState!,
        activeTab: WizardTabTypes.JMeter
      };
      return {...state, activeProject, wizardState};
    }

    default:
      return state;
  }
}

export function selector(appState: AppState): NewProjectWizardState {
  return {activeProject: appState.activeProject, wizardState: appState.wizardState};
}
