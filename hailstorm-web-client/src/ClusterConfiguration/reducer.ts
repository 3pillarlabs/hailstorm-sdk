import { NewProjectWizardState, NewProjectWizardProgress } from "../NewProjectWizard/domain";
import { ClusterConfigurationActions, ClusterConfigurationActionTypes } from "./actions";
import { Project, Cluster } from "../domain";

export function reducer(state: NewProjectWizardState, action: ClusterConfigurationActions): NewProjectWizardState {
  switch (action.type) {
    case ClusterConfigurationActionTypes.ActivateCluster: {
      let activeCluster: Cluster;
      if (!action.payload && state.activeProject!.clusters && state.activeProject!.clusters.length > 0) {
        activeCluster = state.activeProject!.clusters[0];
      } else {
        activeCluster = action.payload!;
      }

      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeCluster};
      return {...state, wizardState};
    }

    case ClusterConfigurationActionTypes.RemoveCluster: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeCluster: undefined};
      const activeProject: Project = {...state.activeProject!};
      if (action.payload && action.payload.id !== undefined && activeProject.clusters !== undefined) {
        activeProject.clusters = activeProject.clusters.filter((value) => value.id !== action.payload!.id);
        if (activeProject.clusters.length === 0) {
          activeProject.clusters = undefined;
        }
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
      return {...state, wizardState, activeProject};
    }

    case ClusterConfigurationActionTypes.SetClusterConfiguration: {
      const activeProject: Project = {...state.activeProject!, clusters: action.payload};
      return {...state, activeProject};
    }

    case ClusterConfigurationActionTypes.ChooseClusterOption: {
      const wizardState: NewProjectWizardProgress = {...state.wizardState!, activeCluster: undefined};
      return {...state, wizardState};
    }

    default:
      break;
  }

  return state;
}
