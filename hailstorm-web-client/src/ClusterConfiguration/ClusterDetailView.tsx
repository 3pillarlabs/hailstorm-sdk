import React from 'react';
import { Cluster, AmazonCluster, DataCenterCluster } from '../domain';
import { EditAWSCluster } from './EditAWSCluster';
import { DataCenterView } from './DataCenterView';

export function ClusterDetailView({
  cluster
}: {
  cluster: Cluster;
}) {

  if (cluster.type === 'AWS') {
    return (<EditAWSCluster cluster={cluster as AmazonCluster} />);
  }

  if (cluster.type === 'DataCenter') {
    return (<DataCenterView cluster={cluster as DataCenterCluster} />);
  }

  return null;
}
