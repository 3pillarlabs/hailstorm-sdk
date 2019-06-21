import React, { useState } from 'react';
import { WizardStep } from './WizardStep';
import styles from './NewProjectWizard.module.scss';
import { Route, RouteComponentProps } from 'react-router';
import { ProjectForm } from '../ProjectForm';
import { JMeterConfiguration } from '../JMeterConfiguration';
import { ClusterConfiguration } from '../ClusterConfiguration';
import { SummaryView } from './SummaryView';
import { History } from 'history';

interface NewProjectWizardState {
  activeTab: string;
  done?: {[key: string]: boolean },
  projectId?: string | number;
}

export const NewProjectWizard: React.FC = () => {
  const [state, dispatch] = useState<NewProjectWizardState>({
    activeTab: 'project',
    done: {}
  });

  return (
    <div className="container">
      <div className="columns">
        <div className="column is-3">
          <div className={styles.stepList}>
            <WizardStep
              title="1"
              linkTo={`/wizard/projects/${state.projectId ? state.projectId : "new"}`}
              first={true}
              isActive={isActive(state, 'project')}
              done={state.done && state.done['project']}
              onClick={() => dispatch({...state, activeTab: 'project'})}
            >
              Project
            </WizardStep>
            <WizardStep
              title="2"
              linkTo={`/wizard/projects/${state.projectId}/jmeter_plans`}
              isActive={isActive(state, 'jmeter_plans')}
              done={state.done && state.done['jmeter_plans']}
              onClick={() => dispatch({...state, activeTab: 'jmeter_plans'})}
            >
              JMeter
            </WizardStep>
            <WizardStep
              title="3"
              linkTo={`/wizard/projects/${state.projectId}/clusters`}
              isActive={isActive(state, 'clusters')}
              done={state.done && state.done['clusters']}
              onClick={() => dispatch({...state, activeTab: 'clusters'})}
            >
              Cluster
            </WizardStep>
            <WizardStep
              title="4"
              linkTo={`/wizard/projects/${state.projectId}/review`}
              last={true}
              isActive={isActive(state, 'review')}
              done={state.done && state.done['review']}
              onClick={() => dispatch({...state, activeTab: 'review'})}
            >
              Review
            </WizardStep>
          </div>
        </div>
        <div className="column is-9">
          <Route
            exact={true}
            path="/wizard/projects/:id"
            render={(routeProps) => projectForm(routeProps, dispatch, state)} />
          <Route
            path="/wizard/projects/:id/jmeter_plans"
            render={(routeProps) => jMeterForm(routeProps, dispatch, state)} />
          <Route path="/wizard/projects/:id/clusters"
            render={(routeProps) => clusterForm(routeProps, dispatch, state)} />
          <Route path="/wizard/projects/:id/review"
            render={(routeProps) => <SummaryView transition={() => routeProps.history.push(`/projects/${state.projectId}`)} />} />
        </div>
      </div>
    </div>
  );
}

function isActive(state: NewProjectWizardState, tabCode: string) {
  return state.activeTab === tabCode;
}

function projectForm(routeProps: RouteComponentProps,
                     dispatch: React.Dispatch<React.SetStateAction<NewProjectWizardState>>,
                     state: NewProjectWizardState): JSX.Element {
  return <ProjectForm {...routeProps} transition={generateProjectTransition(dispatch, routeProps.history, state)} />;
}

function generateProjectTransition(dispatch: React.Dispatch<React.SetStateAction<NewProjectWizardState>>,
                                   history: History,
                                   state: NewProjectWizardState) {
  return (projectId: string | number) => {
    history.push(`/wizard/projects/${projectId}/jmeter_plans`);
    dispatch({...state, activeTab: 'jmeter_plans', done: {...state.done, project: true}, projectId});
  };
}

function jMeterForm(routeProps: RouteComponentProps,
                    dispatch: React.Dispatch<React.SetStateAction<NewProjectWizardState>>,
                    state: NewProjectWizardState): JSX.Element {
  return <JMeterConfiguration {...routeProps} transition={generateJMeterTransition(dispatch, routeProps.history, state)} />;
}

function generateJMeterTransition(dispatch: React.Dispatch<React.SetStateAction<NewProjectWizardState>>,
                                  history: History,
                                  state: NewProjectWizardState) {
  return () => {
    history.push(`/wizard/projects/${state.projectId}/clusters`);
    dispatch({...state, activeTab: 'clusters', done: {...state.done, jmeter_plans: true}});
  };
}

function clusterForm(routeProps: RouteComponentProps,
                     dispatch: React.Dispatch<React.SetStateAction<NewProjectWizardState>>,
                     state: NewProjectWizardState): JSX.Element {
  return <ClusterConfiguration {...routeProps} transition={generateClusterTransition(dispatch, routeProps.history, state)} />;
}

function generateClusterTransition(dispatch: React.Dispatch<React.SetStateAction<NewProjectWizardState>>,
                history: History,
                state: NewProjectWizardState) {
  return () => {
    history.push(`/wizard/projects/${state.projectId}/review`);
    dispatch({...state, activeTab: 'review', done: {...state.done, clusters: true}});
  };
}
