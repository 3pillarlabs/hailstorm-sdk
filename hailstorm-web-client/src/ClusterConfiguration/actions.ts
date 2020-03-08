import { Action } from "../store";
import { Cluster } from "../domain";

export enum ClusterConfigurationActionTypes {
  ActivateCluster = '[ClusterConfiguration ActivateCluster',
  RemoveCluster = '[ClusterConfiguration] RemoveCluster',
  SaveCluster = '[ClusterConfiguration] SaveCluster',
  SetClusterConfiguration = '[ClusterConfiguration] SetClusterConfiguration',
  ChooseClusterOption = '[ClusterConfiguration] ChooseClusterOption',
  UnsetClusters = '[ClusterConfiguration] UnsetClusters'
}

export class ActivateClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.ActivateCluster;
  constructor(public payload?: Cluster) {}
}

export class RemoveClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.RemoveCluster;
  constructor(public payload?: Cluster) {}
}

export class SaveClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.SaveCluster;
  constructor(public payload: Cluster) {}
}

export class SetClusterConfigurationAction implements Action {
  readonly type = ClusterConfigurationActionTypes.SetClusterConfiguration;
  constructor(public payload: Cluster[]) {}
}

export class ChooseClusterOptionAction implements Action {
  readonly type = ClusterConfigurationActionTypes.ChooseClusterOption;
  constructor() {}
}

export class UnsetClustersAction implements Action {
  readonly type = ClusterConfigurationActionTypes.UnsetClusters;
  constructor() {}
}

export type ClusterConfigurationActions =
  | ActivateClusterAction
  | RemoveClusterAction
  | SaveClusterAction
  | SetClusterConfigurationAction
  | ChooseClusterOptionAction
  | UnsetClustersAction;
