import React, { useState, useContext, useEffect } from 'react';
import { JMeterPlanList } from '../JMeterPlanList';
import { ClusterList } from '../ClusterConfiguration/ClusterList';
import { ReportsList } from '../ReportsList/ReportsList';
import { ControlPanel } from './ControlPanel';
import { AppStateContext } from '../appStateContext';
import { ApiFactory } from '../api';
import { SetJMeterConfigurationAction } from '../JMeterConfiguration/actions';
import { SetClusterConfigurationAction } from '../ClusterConfiguration/actions';

export const ProjectWorkspaceMain: React.FC = () => {
  const [loadReports, setLoadReports] = useState<boolean>(true);
  const reloadReports = () => setLoadReports(true);
  const {appState, dispatch} = useContext(AppStateContext);

  useEffect(() => {
    console.debug('ProjectWorkspaceMain#useEffect()');
    if (appState.activeProject && appState.activeProject.jmeter === undefined) {
      ApiFactory()
        .jmeter()
        .list(appState.activeProject.id)
        .then((data) => dispatch(new SetJMeterConfigurationAction(data)));
    }

    if (appState.activeProject && appState.activeProject.clusters === undefined) {
      ApiFactory()
        .clusters()
        .list(appState.activeProject.id)
        .then((clusters) => dispatch(new SetClusterConfigurationAction(clusters)));
    }
  }, []);

  return (
    <div className="columns workspace-main">
      <div className="column is-3">
        <JMeterPlanList
          showEdit={true}
          jmeter={
            appState.activeProject && appState.activeProject.jmeter ?
            appState.activeProject.jmeter :
            {files: []}
          }
          disableEdit={appState.activeProject && (appState.activeProject.running || appState.activeProject.interimState !== undefined)}
        />
        <ClusterList clusters={appState.activeProject ? appState.activeProject.clusters : undefined} />
      </div>
      <div className="column is-6">
        <ControlPanel {...{reloadReports}} />
      </div>
      <div className="column is-3">
        <ReportsList {...{loadReports, setLoadReports}} />
      </div>
    </div>
  );
}
