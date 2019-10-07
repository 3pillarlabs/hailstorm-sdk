import React, { useContext, useEffect, useState } from 'react';
import { WizardStepTitle, WizardStepTitleProps } from './WizardStepTitle';
import styles from './NewProjectWizard.module.scss';
import { Route, RouteComponentProps, withRouter } from 'react-router';
import { ProjectConfiguration } from '../ProjectConfiguration';
import { JMeterConfiguration } from '../JMeterConfiguration';
import { ClusterConfiguration } from '../ClusterConfiguration';
import { SummaryView } from './SummaryView';
import { AppStateContext } from '../appStateContext';
import { WizardTabTypes, NewProjectWizardProgress } from './domain';
import { ActivateTabAction, StayInProjectSetupAction, ProjectSetupCancelAction } from './actions';
import { Loader, LoaderSize } from '../Loader/Loader';
import { UnsavedChangesPrompt } from '../Modal/UnsavedChangesPrompt';

interface LabeledWizardStepTitleProps extends WizardStepTitleProps {
  label: string;
}

const RouterlessNewProjectWizard: React.FC<RouteComponentProps> = ({history}) => {
  const {appState, dispatch} = useContext(AppStateContext);
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    console.debug('NewProjectWizard#useEffect(appState.wizardState)');
    if (!appState.wizardState) return;
    switch (appState.wizardState.activeTab) {
      case WizardTabTypes.Project:
        if (appState.activeProject) {
          history.push(`/wizard/projects/${appState.activeProject.id}`);
        }

        break;

      case WizardTabTypes.JMeter:
        history.push(`/wizard/projects/${appState.activeProject!.id}/jmeter_plans`);
        break;

      case WizardTabTypes.Cluster:
        history.push(`/wizard/projects/${appState.activeProject!.id}/clusters`);
        break;

      case WizardTabTypes.Review:
        history.push(`/wizard/projects/${appState.activeProject!.id}/review`);
        break;

      default:
        break;
    }

    if (appState.wizardState.confirmCancel) {
      setShowModal(true);
    }
  }, [appState.wizardState]);

  useEffect(() => {
    console.debug('NewProjectWizard#useEffect(appState)');
    if (!appState.wizardState) {
      if (appState.activeProject) {
        history.push(`/projects/${appState.activeProject.id}`);
      } else {
        history.push('/projects');
      }
    }
  }, [appState]);

  if (!appState.wizardState) {
    console.debug('!appState.wizardState return');
    return <Loader size={LoaderSize.APP} />;
  }

  const state = appState.wizardState!;
  const projectKey = appState.activeProject ? appState.activeProject.id : 'new';
  const wizardSteps: Array<LabeledWizardStepTitleProps> = [
    {
      tab: WizardTabTypes.Project,
      linkTo: `/wizard/projects/${projectKey}`,
      reachable: state.activeTab !== WizardTabTypes.Project,
      label: 'Project'
    },
    {
      tab: WizardTabTypes.JMeter,
      linkTo: `/wizard/projects/${projectKey}/jmeter_plans`,
      reachable: state.done[WizardTabTypes.Project] !== undefined,
      label: 'JMeter'
    },
    {
      tab: WizardTabTypes.Cluster,
      linkTo: `/wizard/projects/${projectKey}/clusters`,
      reachable: state.done[WizardTabTypes.JMeter] !== undefined,
      label: 'Cluster'
    },
    {
      tab: WizardTabTypes.Review,
      linkTo: `/wizard/projects/${projectKey}/review`,
      reachable: state.done[WizardTabTypes.Cluster] !== undefined,
      label: 'Review'
    },
  ]
  .map((partialStep) => ({
    ...makePartialStep({...partialStep, dispatch, state}),
    linkTo: partialStep.linkTo,
    reachable: partialStep.reachable,
    label: partialStep.label
  }))
  .map<LabeledWizardStepTitleProps>((step, index) => ({
    ...step,
    title: (index + 1).toString(),
    first: index === 0,
    last: index === 3
  }));

  return (
    <div className="container">
      <div className="columns">
        <div className="column is-3">
          <div className={styles.stepList}>
          {wizardSteps.map((step) => (
            <WizardStepTitle key={step.title} {...{...step}}>{step.label}</WizardStepTitle>
          ))}
          </div>
        </div>
        <div className="column is-9">
          <Route
            exact={true}
            path="/wizard/projects/:id"
            component={ProjectConfiguration} />
          <Route
            path="/wizard/projects/:id/jmeter_plans"
            component={JMeterConfiguration} />
          <Route
            path="/wizard/projects/:id/clusters"
            component={ClusterConfiguration} />
          <Route
            path="/wizard/projects/:id/review"
            component={SummaryView} />
        </div>
      </div>
      <UnsavedChangesPrompt
        {...{showModal, setShowModal}}
        hasUnsavedChanges={
          appState.activeProject !== undefined &&
          appState.wizardState &&
          !appState.wizardState.done[WizardTabTypes.Review]
        }
        shouldUpdateNavChange={(location) => (location.pathname.match(/^\/wizard/) === null)}
        handleCancel={() => dispatch(new StayInProjectSetupAction())}
        handleConfirm={() => dispatch(new ProjectSetupCancelAction())}
      >
        <p>The project set up is not complete. Are you sure you want to exit the wizard now?</p>
      </UnsavedChangesPrompt>
    </div>
  );
}

function makePartialStep({
  tab,
  state,
  dispatch
}: {
  tab: WizardTabTypes;
  state: NewProjectWizardProgress;
  dispatch: React.Dispatch<any>;
}): {
  isActive: boolean;
  done: boolean;
  onClick: () => void;
}  {

  return {
    isActive: state.activeTab === tab,
    done: state.done[tab] !== undefined,
    onClick: () => dispatch(new ActivateTabAction(tab)),
  };
}

export const NewProjectWizard = withRouter(RouterlessNewProjectWizard);
