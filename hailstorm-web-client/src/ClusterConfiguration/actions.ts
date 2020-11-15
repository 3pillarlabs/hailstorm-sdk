import { Action } from "../store";
import { Cluster } from "../domain";

export enum ClusterConfigurationActionTypes {
  ActivateCluster = '[ClusterConfiguration ActivateCluster',
  RemoveCluster = '[ClusterConfiguration] RemoveCluster',
  CreateCluster = '[ClusterConfiguration] CreateCluster',
  SetClusterConfiguration = '[ClusterConfiguration] SetClusterConfiguration',
  ChooseClusterOption = '[ClusterConfiguration] ChooseClusterOption',
  UpdateCluster = '[ClusterConfiguration] UpdateCluster',
}

export class ActivateClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.ActivateCluster;
  constructor(public payload?: Cluster) {}
}

export class RemoveClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.RemoveCluster;
  constructor(public payload?: Cluster) {}
}

export class CreateClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.CreateCluster;
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

export class UpdateClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.UpdateCluster;
  constructor(public payload: Cluster) {}
}

export type ClusterConfigurationActions =
  | ActivateClusterAction
  | RemoveClusterAction
  | CreateClusterAction
  | SetClusterConfigurationAction
  | ChooseClusterOptionAction
  | UpdateClusterAction;
