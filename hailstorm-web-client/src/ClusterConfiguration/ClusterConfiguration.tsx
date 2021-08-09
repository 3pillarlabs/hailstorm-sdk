import React, { useContext, useEffect, useState } from 'react';
import { AppStateContext } from '../appStateContext';
import { ClusterSetupCompletedAction } from '../NewProjectWizard/actions';
import { CancelLink, BackLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes, NewProjectWizardProgress } from "../NewProjectWizard/domain";
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { selector } from '../NewProjectWizard/reducer';
import { Project, Cluster, AmazonCluster, DataCenterCluster } from '../domain';
import clusterStyles from './ClusterConfiguration.module.scss';
import { ClusterList } from '../ClusterList';
import { ActivateClusterAction, ChooseClusterOptionAction, SetClusterConfigurationAction } from './actions';
import { NewAWSCluster } from './NewAWSCluster';
import { EditAWSCluster } from './EditAWSCluster';
import { DataCenterForm } from './DataCenterForm';
import { DataCenterView } from './DataCenterView';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader/Loader';

export const ClusterConfiguration: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const [showLoader, setShowLoader] = useState(false);
  const state = selector(appState);

  useEffect(() => {
    console.debug("ClusterConfiguration#useEffect()");
    if (!state.activeProject) return;

    if (state.activeProject.clusters === undefined) {
      setShowLoader(true);
      ApiFactory()
        .clusters()
        .list(state.activeProject.id)
        .then((clusters) => {
          dispatch(new SetClusterConfigurationAction(clusters));
          setShowLoader(false);
        });
    }
  }, []);

  if (showLoader) {
    return (<Loader size={LoaderSize.APP} />);
  }

  return (
    <>
    <StepHeader activeProject={state.activeProject!} wizardState={state.wizardState!} {...{dispatch}} />
    <div className={styles.stepBody}>
      <StepContent wizardState={state.wizardState!} activeProject={state.activeProject!} {...{dispatch}} />
      <StepFooter {...{dispatch}} activeProject={state.activeProject!} />
    </div>
    </>
  );
}

function StepHeader({
  activeProject,
  wizardState,
  dispatch
}: {
  activeProject: Project;
  wizardState: NewProjectWizardProgress;
  dispatch: React.Dispatch<any>;
}) {
  return (
    <div className={`columns ${styles.stepHeader}`}>
      <div className="column is-10">
        <h3 className="title is-3">{activeProject.title} &mdash; Clusters</h3>
      </div>
      <div className="column is-2">
        <button
          role="Add Cluster"
          className="button is-link is-medium is-pulled-right"
          disabled={wizardState.activeCluster === undefined || wizardState.activeCluster.id === undefined}
          onClick={() => dispatch(new ChooseClusterOptionAction())}
        >
          Add Cluster
        </button>
      </div>
    </div>
  );
}

function StepContent({
  wizardState,
  activeProject,
  dispatch
}: {
  wizardState: NewProjectWizardProgress;
  activeProject: Project;
  dispatch: React.Dispatch<any>;
}) {
  return (
    <div className={`columns ${styles.stepContent}`}>
      <div className="column is-two-fifths">
        <ClusterList
          clusters={activeProject.clusters}
          onSelectCluster={(cluster) => dispatch(new ActivateClusterAction(cluster))}
          activeCluster={wizardState.activeCluster}
          showDisabledCluster={true}
        />
      </div>
      <div className="column is-three-fifths">
        {!wizardState.activeCluster && (
        <>
        {!activeProject.clusters && (
        <div className="notification is-info">
          There are no clusters yet. A cluster is used for load generation. <br/>
          <strong>You need to have at least one cluster.</strong>
        </div>)}
        <ClusterChoice clusters={activeProject.clusters} {...{dispatch}} />
        </>)}
        {wizardState.activeCluster && wizardState.activeCluster.type === 'AWS' && (
        (wizardState.activeCluster.id === undefined ? (
        <NewAWSCluster {...{dispatch, activeProject}} />
        ): (
        <EditAWSCluster
          cluster={wizardState.activeCluster! as AmazonCluster}
          {...{dispatch, activeProject}}
        />)))}
        {wizardState.activeCluster && wizardState.activeCluster.type === 'DataCenter' && (
        (wizardState.activeCluster.id === undefined ? (
        <DataCenterForm {...{dispatch, activeProject}} />
        ) : (
        <DataCenterView
          cluster={wizardState.activeCluster! as DataCenterCluster}
          {...{dispatch, activeProject}}
        />)))}
      </div>
    </div>
  );
}

function ClusterChoice({
  clusters,
  dispatch
}: {
  clusters?: Cluster[];
  dispatch: React.Dispatch<any>;
}) {
  return (
    <>
      <h5 className="title is-5">
        Choose how you want to create your {!clusters || clusters.length === 0 ? 'first' : 'next'} cluster...
      </h5>
      <div className="columns">
        <ChoiceCard>
          <ChoiceCardLink action={new ActivateClusterAction({title: '', type: 'AWS'})} {...{dispatch}}>
            <span className="icon is-medium">
              <i className="fab fa-aws"></i>
            </span>
            <span>AWS</span>
          </ChoiceCardLink>
          <p className="subtitle">Choose Amazon Web Services (AWS) when...</p>
          <UnorderedList className={clusterStyles.whyList}>
            <ListItem>The application is reachable publicly, or from AWS.</ListItem>
            <ListItem>The application is hosted on AWS.</ListItem>
          </UnorderedList>
        </ChoiceCard>
        <ChoiceCard>
          <ChoiceCardLink action={new ActivateClusterAction({title: '', type: 'DataCenter'})} {...{dispatch}}>
            <span className="icon is-medium">
              <i className="fas fa-network-wired"></i>
            </span>
            <span>Data Center</span>
          </ChoiceCardLink>
          <p className="subtitle">Choose a Data Center when...</p>
          <UnorderedList className={clusterStyles.whyList}>
            <ListItem>The application is privately hosted in the data center.</ListItem>
            <ListItem>Network latency needs to be minimized as much as possible.</ListItem>
          </UnorderedList>
        </ChoiceCard>
      </div>
      {clusters && clusters.length > 0 && (
      <div className="control has-text-centered">
        <a className="is-link" role="Cancel Choice" onClick={() => dispatch(new ActivateClusterAction())}>Cancel</a>
      </div>
      )}
    </>
  )
}

function ChoiceCard({children}: React.PropsWithChildren<{}>) {
  return (
    <div className="column is-half">
      <div className={clusterStyles.choiceCard}>
        {children}
      </div>
    </div>
  )
}

function ChoiceCardLink({
  action,
  dispatch,
  children
}: React.PropsWithChildren<{action: ActivateClusterAction, dispatch: React.Dispatch<any>}>) {
  return (
    <a
      className={`button is-link is-large is-fullwidth ${clusterStyles.cardButton}`}
      onClick={() => dispatch(action)}
    >
      {children}
    </a>
  )
}

function UnorderedList({children, className}: React.PropsWithChildren<{className?: string}>) {
  return (
    <ul className={`fa-ul${className ? ` ${className}` : ''}`}>
      {children}
    </ul>
  )
}

function ListItem({children}: React.PropsWithChildren<{}>) {
  return (
    <li>
      <span className="fa-li"><i className="fas fa-check-circle"></i></span>
      {children}
    </li>
  )
}

function StepFooter({
  dispatch,
  activeProject
}: {
  dispatch: React.Dispatch<any>;
  activeProject: Project;
}) {
  return <div className="level">
    <div className="level-left">
      <div className="level-item">
        <CancelLink {...{ dispatch }} />
      </div>
      <div className="level-item">
        <BackLink {...{ dispatch, tab: WizardTabTypes.JMeter }} />
      </div>
    </div>
    <div className="level-right">
      <button
        disabled={activeProject.clusters === undefined || activeProject.clusters.every((value) => value.disabled)}
        className="button is-primary"
        onClick={() => dispatch(new ClusterSetupCompletedAction())}
      >
        Next
      </button>
    </div>
  </div>;
}
