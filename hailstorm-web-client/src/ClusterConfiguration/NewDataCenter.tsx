import React, { useState } from 'react';
import { FileServer } from '../FileUpload/fileServer';
import { ApiFactory } from '../api';
import { Project, DataCenterCluster } from '../domain';
import { CreateClusterAction } from './actions';
import { SavedFile } from '../FileUpload/domain';
import { ClusterViewHeader } from './ClusterViewHeader';
import { useNotifications } from '../app-notifications';
import { DataCenterForm } from './DataCenterForm';

export function NewDataCenter({
  dispatch,
  activeProject
}: {
  dispatch: React.Dispatch<any>;
  activeProject: Project;
}) {
  const [pemFile, setPemFile] = useState<File>();
  const [machines, setMachines] = useState<string[]>([]);
  const {notifySuccess} = useNotifications();

  const onSubmit = async ({
    userName,
    sshPort,
    title,
  }: {
    title: string;
    userName: string;
    sshPort: number;
  }) => {
    return FileServer
      .sendFile(pemFile!, undefined, activeProject.code)
      .begin()
      .then(async ({id}: SavedFile) => {
        const attrs: DataCenterCluster = {
          userName,
          sshPort,
          title,
          machines,
          sshIdentity: { name: pemFile!.name, path: id },
          type: 'DataCenter',
        };

        const data = await ApiFactory().clusters().create(activeProject.id, attrs);
        dispatch(new CreateClusterAction(data));
        notifySuccess(`Saved ${data.title} cluster configuration`);
        return data;
      });
  };

  return (
    <div className="card">
      <ClusterViewHeader
        title="Create a new cluster in your Data Center"
        icon={(<i className="fas fa-network-wired"></i>)}
      />
      <DataCenterForm {...{
        pemFile,
        machines,
        onSubmit,
        setPemFile,
        activeProject,
        setMachines,
        dispatch
      }} />
    </div>
  )
}


