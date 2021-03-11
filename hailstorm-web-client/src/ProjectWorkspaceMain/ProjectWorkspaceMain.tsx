import React, { useState, useContext, useEffect } from 'react';
import { JMeterPlanList } from '../JMeterPlanList';
import { ClusterList } from '../ClusterList';
import { ReportsList } from '../ReportsList';
import { ControlPanel } from './ControlPanel';
import { AppStateContext } from '../appStateContext';
import { ApiFactory } from '../api';
import { SetJMeterConfigurationAction } from '../JMeterConfiguration/actions';
import { SetClusterConfigurationAction } from '../ClusterConfiguration/actions';
import { WizardTabTypes } from '../NewProjectWizard/domain';
import { Redirect } from 'react-router';
import { TerminateProject, highlightTerminate } from '../DangerProjectSettings/TerminateProject';

export const ProjectWorkspaceMain: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const [loadReports, setLoadReports] = useState<boolean>(true);
  const [redirectLocation, setRedirectLocation] = useState<WizardTabTypes>();
  const [waitingForReport, setWaitingForReport] = useState(false);
  const reloadReports = () => setLoadReports(true);

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

  if (redirectLocation) {
    let pathname: string;
    const projectState = appState.activeProject ? {...appState.activeProject} : undefined;
    if (redirectLocation === WizardTabTypes.JMeter) {
      pathname = `/wizard/projects/${appState.activeProject!.id}/jmeter_plans`;

    } else if (redirectLocation === WizardTabTypes.Cluster) {
      if (projectState) {
        delete projectState.clusters;
      }

      pathname = `/wizard/projects/${appState.activeProject!.id}/clusters`;
    } else {
      pathname = `/wizard/projects/${appState.activeProject!.id}`
    }

    return (<Redirect to={{pathname, state: {project: projectState, activeTab: redirectLocation}}} />);
  }

  return (
    <div className="columns workspace-main">
      <div className="column is-3">
        <JMeterPlanList
          showEdit={true}
          jmeter={
            appState.activeProject && appState.activeProject.jmeter
              ? appState.activeProject.jmeter
              : { files: [] }
          }
          disableEdit={
            appState.activeProject &&
            (appState.activeProject.running ||
              appState.activeProject.interimState !== undefined)
          }
          onEdit={() => setRedirectLocation(WizardTabTypes.JMeter)}
        />
        <ClusterList
          clusters={
            appState.activeProject ? appState.activeProject.clusters : undefined
          }
          showEdit={true}
          disableEdit={
            appState.activeProject &&
            (appState.activeProject.running ||
              appState.activeProject.interimState !== undefined)
          }
          onEdit={() => setRedirectLocation(WizardTabTypes.Cluster)}
        />
      </div>
      <div className="column is-6">
        <ControlPanel {...{ reloadReports, setWaitingForReport, dispatch }} project={appState.activeProject!} />
      </div>
      <div className="column is-3">
        {appState.activeProject && highlightTerminate(appState.activeProject) && (
          <div className="message is-warning">
            <TerminateProject display={"SingleColumn"} />
          </div>
        )}
        <ReportsList {...{ loadReports, setLoadReports, waitingForReport }} project={appState.activeProject!} />
      </div>
    </div>
  );
}
