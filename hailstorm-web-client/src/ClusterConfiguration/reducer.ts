import { NewProjectWizardState, NewProjectWizardProgress, WizardTabTypes } from "../NewProjectWizard/domain";
import { ClusterConfigurationActions, ClusterConfigurationActionTypes } from "./actions";
import { Project, Cluster } from "../domain";

export function reducer(state: NewProjectWizardState, action: ClusterConfigurationActions): NewProjectWizardState {
  switch (action.type) {
    case ClusterConfigurationActionTypes.ActivateCluster: {
      let modifiedAfterReview = false;
      let activeCluster: Cluster;
      let activeProject: Project | undefined = undefined;
      if (!action.payload && state.activeProject!.clusters && state.activeProject!.clusters.length > 0) {
        activeCluster = state.activeProject!.clusters[0];
      } else {
        activeCluster = action.payload!;
        if (activeCluster.disabled === false) {
          delete activeCluster.disabled;
          if (state.activeProject!.clusters) {
            activeProject = {...state.activeProject!};
            activeProject.clusters = activeProject.clusters!.map((value) => value.id === activeCluster.id ? activeCluster : value);
          }

          modifiedAfterReview = true;
        }
      }

      let wizardState: NewProjectWizardProgress = {...state.wizardState!, activeCluster};
      if (modifiedAfterReview) wizardState = {...wizardState, modifiedAfterReview};

      let nextState = {...state, wizardState};
      if (activeProject) nextState = {...nextState, activeProject}
      return nextState;
    }

    case ClusterConfigurationActionTypes.RemoveCluster: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeCluster: undefined};
      const activeProject: Project = {...state.activeProject!};
      if (action.payload && action.payload.id !== undefined && activeProject.clusters !== undefined) {
        if (action.payload.disabled === true) {
          activeProject.clusters = activeProject.clusters.map((value) => value.id === action.payload!.id ? action.payload! : value);
        } else {
          activeProject.clusters = activeProject.clusters.filter((value) => value.id !== action.payload!.id);
        }

        if (activeProject.clusters.every((cluster) => cluster.disabled)) {
          activeProject.incomplete = true;
        }

        if (activeProject.clusters.length === 0) {
          activeProject.clusters = undefined;
          activeProject.incomplete = true;
        } else {
          wizardState.activeCluster = action.payload.disabled ? action.payload : activeProject.clusters![0];
        }
      }

      if (wizardState.done[WizardTabTypes.Review]) {
        wizardState.modifiedAfterReview = true;
      }

      return {...state, wizardState, activeProject};
    }

    case ClusterConfigurationActionTypes.SaveCluster: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeCluster: action.payload};
      const activeProject: Project = {...state.activeProject!};
      if (activeProject.clusters === undefined) {
        activeProject.clusters = [];
      }

      activeProject.clusters = [...activeProject.clusters, action.payload];
      if (wizardState.done[WizardTabTypes.Review]) {
        wizardState.modifiedAfterReview = true;
      }

      return {...state, wizardState, activeProject};
    }

    case ClusterConfigurationActionTypes.SetClusterConfiguration: {
      const activeProject: Project = {...state.activeProject!, clusters: action.payload};
      if (state.wizardState && state.wizardState.activeTab === WizardTabTypes.Cluster &&
          activeProject.clusters!.length > 0 && !state.wizardState.activeCluster
      ) {
        const wizardState = {...state.wizardState};
        wizardState.activeCluster = activeProject.clusters![0];
        return {...state, activeProject, wizardState};
      }

      return {...state, activeProject};
    }

    case ClusterConfigurationActionTypes.ChooseClusterOption: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeCluster: undefined};
      return {...state, wizardState};
    }

    case ClusterConfigurationActionTypes.UnsetClusters: {
      const activeProject = {...state.activeProject!};
      activeProject.clusters = undefined;
      return {...state, activeProject};
    }

    default:
      break;
  }

  return state;
}
