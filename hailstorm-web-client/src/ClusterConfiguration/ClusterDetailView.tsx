import React from 'react';
import { Cluster, AmazonCluster, DataCenterCluster } from '../domain';
import { AWSView } from './AWSView';
import { DataCenterView } from './DataCenterView';

export function ClusterDetailView({
  cluster
}: {
  cluster: Cluster;
}) {

  if (cluster.type === 'AWS') {
    return (<AWSView cluster={cluster as AmazonCluster} />);
  }

  if (cluster.type === 'DataCenter') {
    return (<DataCenterView cluster={cluster as DataCenterCluster} />);
  }

  return null;
}
