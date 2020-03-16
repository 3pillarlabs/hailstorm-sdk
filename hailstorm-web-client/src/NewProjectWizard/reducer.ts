import {
  NewProjectWizardActions,
  NewProjectWizardActionTypes,
  ActivateTabAction,
  CreateProjectAction,
  EditInProjectWizard,
  UpdateProjectTitleAction
} from "./actions";
import { NewProjectWizardState, WizardTabTypes, NewProjectWizardProgress } from "./domain";
import { AppState } from "../store";
import { Project } from "../domain";

export function reducer(state: NewProjectWizardState, action: NewProjectWizardActions): NewProjectWizardState {
  let nextState: NewProjectWizardState;
  switch (action.type) {
    case NewProjectWizardActionTypes.ProjectSetup:
      nextState = onProjectSetup(state);
      break;

    case NewProjectWizardActionTypes.ProjectSetupCancel:
      nextState = onProjectSetupCancel(state);
      break;

    case NewProjectWizardActionTypes.ActivateTab:
      nextState = onActivateTab(state, action);
      break;

    case NewProjectWizardActionTypes.CreateProject:
      nextState = onCreateProject(state, action);
      break;

    case NewProjectWizardActionTypes.JMeterSetupCompleted:
      nextState = onJMeterSetupCompleted(state);
      break;

    case NewProjectWizardActionTypes.ClusterSetupCompleted:
      nextState = onClusterSetupCompleted(state);
      break;

    case NewProjectWizardActionTypes.ReviewCompleted:
      nextState = onReviewCompleted(state);
      break;

    case NewProjectWizardActionTypes.ConfirmProjectSetupCancel:
      nextState = onConfirmProjectSetupCancel(state);
      break;

    case NewProjectWizardActionTypes.StayInProjectSetup:
      nextState = onStayInProjectSetup(state);
      break;

    case NewProjectWizardActionTypes.UpdateProjectTitle:
      nextState = onUpdateProjectTitle(state, action);
      break;

    case NewProjectWizardActionTypes.EditInProjectWizard:
      nextState = onEditInProjectWizard(state, action);
      break;

    case NewProjectWizardActionTypes.UnsetProject:
      nextState = onUnsetProject(state);
      break;

    case NewProjectWizardActionTypes.SetProjectDeleted:
      nextState = onSetProjectDeleted(state);
      break;

    default:
      nextState = state;
      break;
  }

  return nextState;
}

function onSetProjectDeleted(state: NewProjectWizardState) {
  if (state.wizardState && state.activeProject) {
    const activeProject:Project = {...state.activeProject, destroyed: true};
    const nextState = {...state, activeProject};
    delete nextState.wizardState;
    return nextState;
  }

  return state;
}

function onUnsetProject(state: NewProjectWizardState) {
  if (state.wizardState === undefined) {
    return {...state, activeProject: undefined};
  }

  return state;
}

function onEditInProjectWizard(state: NewProjectWizardState, action: EditInProjectWizard) {
  {
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
    };
    return { ...state, wizardState, activeProject: project };
  }
}

function onUpdateProjectTitle(state: NewProjectWizardState, action: UpdateProjectTitleAction) {
  {
    const activeProject = { ...state.activeProject!, title: action.payload };
    const wizardState: NewProjectWizardProgress = {
      ...state.wizardState!,
      activeTab: WizardTabTypes.JMeter
    };
    if (wizardState && wizardState.done[WizardTabTypes.Review]) {
      wizardState.modifiedAfterReview = true;
    }
    return { ...state, activeProject, wizardState };
  }
}

function onStayInProjectSetup(state: NewProjectWizardState) {
  {
    const wizardState = { ...state.wizardState! };
    delete wizardState.confirmCancel;
    return { ...state, wizardState };
  }
}

function onConfirmProjectSetupCancel(state: NewProjectWizardState) {
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

function onReviewCompleted(state: NewProjectWizardState) {
  {
    const nextState = { ...state };
    if (state.activeProject!.incomplete) {
      const activeProject = { ...state.activeProject! };
      delete activeProject.incomplete;
      nextState.activeProject = activeProject;
    }
    delete nextState.wizardState;
    return nextState;
  }
}

function onClusterSetupCompleted(state: NewProjectWizardState) {
  {
    const wizardState: NewProjectWizardProgress = {
      ...state.wizardState!,
      activeTab: WizardTabTypes.Review,
      done: {
        ...state.wizardState!.done,
        [WizardTabTypes.Cluster]: true
      }
    };
    return { ...state, wizardState };
  }
}

function onJMeterSetupCompleted(state: NewProjectWizardState) {
  {
    const wizardState: NewProjectWizardProgress = {
      ...state.wizardState!,
      activeTab: WizardTabTypes.Cluster,
      done: {
        ...state.wizardState!.done,
        [WizardTabTypes.JMeter]: true
      }
    };
    return { ...state, wizardState };
  }
}

function onCreateProject(state: NewProjectWizardState, action: CreateProjectAction) {
  {
    const wizardState: NewProjectWizardProgress = {
      ...state.wizardState!,
      activeTab: WizardTabTypes.JMeter,
      done: {
        ...state.wizardState!.done,
        [WizardTabTypes.Project]: true
      }
    };
    return { ...state, wizardState, activeProject: action.payload };
  }
}

function onActivateTab(state: NewProjectWizardState, action: ActivateTabAction) {
  {
    const wizardState: NewProjectWizardProgress = { ...state.wizardState!, activeTab: action.payload };
    return { ...state, wizardState };
  }
}

function onProjectSetupCancel(state: NewProjectWizardState) {
  {
    const nextState: NewProjectWizardState = { ...state, activeProject: undefined };
    delete nextState.wizardState;
    return nextState;
  }
}

function onProjectSetup(state: NewProjectWizardState) {
  {
    const nextState: NewProjectWizardState = { ...state, activeProject: undefined };
    return { ...nextState, wizardState: { activeTab: WizardTabTypes.Project, done: {} } };
  }
}

export function selector(appState: AppState): NewProjectWizardState {
  return {activeProject: appState.activeProject, wizardState: appState.wizardState};
}
