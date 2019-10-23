import { Action } from "../store";
import { Cluster } from "../domain";

export enum ClusterConfigurationActionTypes {
  NewCluster = '[ClusterConfiguration [NewCluster]',
  RemoveCluster = '[ClusterConfiguration [RemoveCluster]',
  SaveCluster = '[ClusterConfiguration [SaveCluster]',
  SetClusterConfiguration = '[ClusterConfiguration [SetClusterConfiguration]',
}

export class NewClusterAction implements Action {
  readonly type = ClusterConfigurationActionTypes.NewCluster;
  constructor(public payload: Cluster) {}
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

export type ClusterConfigurationActions =
  | NewClusterAction
  | RemoveClusterAction
  | SaveClusterAction
  | SetClusterConfigurationAction;
