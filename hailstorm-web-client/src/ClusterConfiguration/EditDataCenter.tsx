import React, { useEffect, useState } from 'react';
import { DataCenterCluster, Project } from '../domain';
import { ClusterViewHeader } from './ClusterViewHeader';
import { DataCenterForm } from './DataCenterForm';
import { FileServer } from '../FileUpload/fileServer';
import { ApiFactory } from '../api';
import _ from 'lodash';
import { UpdateClusterAction } from './actions';
import { useNotifications } from '../app-notifications';

export function EditDataCenter({
  cluster,
  activeProject,
  dispatch
}: {
  cluster: DataCenterCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {
  const {notifySuccess, notifyError} = useNotifications();
  const [pemFile, setPemFile] = useState<File>();
  const [machines, setMachines] = useState<string[]>([]);
  const staticField = cluster.disabled || !dispatch;
  const updateCluster = async (values: {
    title: string;
    userName: string;
    sshPort: number;
  }, actions: {
    resetForm: (nextValues?: any | undefined) => void;
  }) => {
    const attrs: {
      [K in keyof DataCenterCluster]?: DataCenterCluster[K]
    } = {};

    ["userName", "sshPort", "title"].forEach((attribute) => {
      const attributeValue = _.get(values, attribute);
      if (_.get(cluster, attribute) !== attributeValue) {
        _.set(attrs, attribute, attributeValue);
      }
    });

    if (cluster.machines !== machines) {
      attrs.machines = machines;
    }

    try {
      let fileId: string | undefined;
      if (pemFile) {
        const rootPromise = FileServer.sendFile(pemFile, undefined, activeProject!.code).begin();
        const response = await rootPromise;
        fileId = response.id;
      }

      if (fileId) {
        _.assign(attrs, { sshIdentity: { name: pemFile!.name, path: fileId } });
      }

      const updatedCluster = await ApiFactory().clusters().update(activeProject!.id, cluster.id!, attrs);
      dispatch && dispatch(new UpdateClusterAction(updatedCluster));
      actions.resetForm(attrs);
      notifySuccess(`Saved ${updatedCluster.title} cluster configuration`);
      return updatedCluster;
    } catch (error) {
      notifyError("Failed to update cluster configuration", error);
      throw error;
    }
  };

  useEffect(() => {
    setMachines(cluster.machines);
  }, [cluster]);

  return (
    <div className="card">
      <ClusterViewHeader
        title={cluster.title}
        icon={(<i className="fas fa-network-wired"></i>)}
      />
      <DataCenterForm
        formMode={staticField ? 'readOnly' : 'edit'}
        {...{
          activeProject,
          cluster,
          dispatch,
          machines,
          setMachines,
          pemFile,
          setPemFile,
        }}
        onSubmit={updateCluster}
      />
    </div>
  )
}
