import React, { useState, useContext, useEffect } from 'react';
import { JMeterPlanList } from '../JMeterConfiguration/JMeterPlanList';
import { ClusterList } from '../ClusterConfiguration/ClusterList';
import { ReportsList } from '../ReportsList/ReportsList';
import { ControlPanel } from './ControlPanel';
import { AppStateContext } from '../appStateContext';
import { ApiFactory } from '../api';
import { SetJMeterConfigurationAction } from '../JMeterConfiguration/actions';

export const ProjectWorkspaceMain: React.FC = () => {
  const [loadReports, setLoadReports] = useState<boolean>(true);
  const reloadReports = () => setLoadReports(true);
  const {appState, dispatch} = useContext(AppStateContext);

  useEffect(() => {
    console.debug('ProjectWorkspaceMain#useEffect()');
    if (appState.activeProject && !appState.activeProject.jmeter) {
      ApiFactory()
        .jmeter()
        .list(appState.activeProject.id)
        .then((data) => dispatch(new SetJMeterConfigurationAction(data)));
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
        />
        <ClusterList />
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
