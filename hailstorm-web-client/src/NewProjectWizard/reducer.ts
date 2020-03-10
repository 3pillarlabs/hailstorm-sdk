import { NewProjectWizardActions, NewProjectWizardActionTypes } from "./actions";
import { NewProjectWizardState, WizardTabTypes, NewProjectWizardProgress } from "./domain";
import { AppState } from "../store";
import { Project } from "../domain";

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
      if (state.activeProject!.incomplete) {
        const activeProject = {...state.activeProject! }
        delete activeProject.incomplete
        nextState.activeProject = activeProject
      }

      delete nextState.wizardState;
      return nextState;
    }

    case NewProjectWizardActionTypes.ConfirmProjectSetupCancel: {
      if (
        !state.activeProject || (
          state.wizardState!.done[WizardTabTypes.Review] &&
          !state.wizardState!.modifiedAfterReview
        )
      ) {
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

      if (wizardState && wizardState.done[WizardTabTypes.Review]) {
        wizardState.modifiedAfterReview = true;
      }

      return {...state, activeProject, wizardState};
    }

    case NewProjectWizardActionTypes.EditInProjectWizard: {
      const project = action.payload.project;
      const done = project.incomplete ? {
        [WizardTabTypes.Project]: true,
      } : {
        [WizardTabTypes.Project]: true,
        [WizardTabTypes.JMeter]: true,
        [WizardTabTypes.Cluster]: true,
        [WizardTabTypes.Review]: true,
      };

      const wizardState: NewProjectWizardProgress = {
        activeTab: project.incomplete || action.payload.activeTab === undefined ? WizardTabTypes.Project : action.payload.activeTab,
        done,
        activeJMeterFile: project.jmeter ? project.jmeter.files[0] : undefined,
        activeCluster: project.clusters && project.clusters.length > 0 ? project.clusters[0] : undefined
      }

      return {...state, wizardState, activeProject: project};
    }

    case NewProjectWizardActionTypes.UnsetProject: {
      if (state.wizardState === undefined) {
        return {...state, activeProject: undefined};
      }

      return state;
    }

    case NewProjectWizardActionTypes.SetProjectDeleted: {
      if (state.wizardState && state.activeProject) {
        const activeProject:Project = {...state.activeProject, destroyed: true};
        const nextState = {...state, activeProject};
        delete nextState.wizardState;
        return nextState;
      }

      return state;
    }

    default:
      return state;
  }
}

export function selector(appState: AppState): NewProjectWizardState {
  return {activeProject: appState.activeProject, wizardState: appState.wizardState};
}
