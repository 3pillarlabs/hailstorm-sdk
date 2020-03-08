import React, { useContext } from 'react';
import { AppStateContext } from '../appStateContext';
import { ReviewCompletedAction, ActivateTabAction } from './actions';
import { CancelLink, BackLink } from './WizardControls';
import { WizardTabTypes } from "./domain";
import styles from './NewProjectWizard.module.scss';
import { JMeter, Cluster } from '../domain';
import { JMeterFileDetail } from '../JMeterConfiguration/JMeterFileDetail';
import { ClusterDetailView } from '../ClusterConfiguration/ClusterDetailView';

export const SummaryView: React.FC = () => {
  const {dispatch, appState} = useContext(AppStateContext);

  return (
    <>
    <div className={`level ${styles.stepHeader}`}>
      <h3 className="title is-3">{appState.activeProject!.title} &mdash; Review</h3>
    </div>
    <div className={styles.stepBody}>
      <div className={styles.stepContent}>
        <JMeterSection {...{dispatch}} jmeter={appState.activeProject!.jmeter!} />
        <hr/>
        <ClusterSection {...{dispatch}} clusters={appState.activeProject!.clusters!} />
        <hr/>
      </div>
      <StepFooter {...{dispatch}} />
    </div>
    </>
  )
}

function StepFooter({
  dispatch
}: {
  dispatch: React.Dispatch<any>;
}) {
  return <div className="level">
    <div className="level-left">
      <div className="level-item">
        <CancelLink {...{ dispatch }} />
      </div>
      <div className="level-item">
        <BackLink {...{ dispatch, tab: WizardTabTypes.Cluster }} />
      </div>
    </div>
    <div className="level-right">
      <div className="level-item">
        <button className="button is-success" onClick={() => dispatch(new ReviewCompletedAction())}>Done</button>
      </div>
    </div>
  </div>;
}

function Section({children, dispatch, tab}: React.PropsWithChildren<{
  dispatch: React.Dispatch<any>;
  tab: WizardTabTypes;
}>) {
  return (
    <div className="level">
      <div className="level-left">
        <div className="level-item">{children}</div>
      </div>
      <div className="level-right">
        <div className="level-item">
          <a className="button" onClick={() => dispatch(new ActivateTabAction(tab))}>Edit</a>
        </div>
      </div>
    </div>
  );
}

function JMeterSection({
  dispatch,
  jmeter,
}: {
  dispatch: React.Dispatch<any>;
  jmeter: JMeter;
}) {
  return (
    <>
    <Section {...{dispatch}} tab={WizardTabTypes.JMeter}>
      <h4 className="title is-4">JMeter</h4>
    </Section>
    <div className="card">
      <div className="card-content">
        <div className="content">
        {jmeter.files.map((jmeterFile) => (
          <JMeterFileDetail {...{jmeterFile}} key={jmeterFile.id} headerTitle={jmeterFile.name} />
        ))}
        </div>
      </div>
    </div>
    </>
  );
}

function ClusterSection({
  dispatch,
  clusters
}: {
  dispatch: React.Dispatch<any>;
  clusters: Cluster[];
}) {
  return (
    <>
    <Section {...{dispatch}} tab={WizardTabTypes.Cluster}>
      <h4 className="title is-4">Clusters</h4>
    </Section>
    <div className="card">
      <div className="card-content">
        <div className="content">
        {clusters.filter((value) => !value.disabled).map((cluster) => (
          <ClusterDetailView {...{cluster}} key={cluster.id} />
        ))}
        </div>
      </div>
    </div>
    </>
  );
}
