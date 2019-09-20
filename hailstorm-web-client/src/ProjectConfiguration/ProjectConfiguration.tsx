import React, { useContext } from 'react';
import { ProjectForm } from './ProjectForm';
import { Field, ErrorMessage } from 'formik';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { ApiFactory } from '../api';
import { AppStateContext } from '../appStateContext';
import { CreateProjectAction, UpdateProjectTitleAction } from '../NewProjectWizard/actions';
import { CancelLink, NextLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes } from '../store';

export const ProjectConfiguration: React.FC = () => {
  const {dispatch, appState} = useContext(AppStateContext);

  return (
    <>
      <h3 className={`title is-3 ${styles.stepHeader}`}>Setup a new Project</h3>
      <div className={styles.stepBody}>
        <ProjectForm
          title={appState.activeProject ? appState.activeProject.title : ''}
          handleSubmit={(values, {setSubmitting}) => {
            setSubmitting(true);
            if (!appState.activeProject) {
              ApiFactory()
                .projects()
                .create({title: values.title})
                .then((project) => {
                  setSubmitting(false);
                  dispatch(new CreateProjectAction(project));
                });
            } else {
              ApiFactory()
                .projects()
                .update(appState.activeProject.id, {title: values.title})
                .then(() => {
                  setSubmitting(false);
                  dispatch(new UpdateProjectTitleAction(values.title!));
                });
            }
          }}
          render={({isSubmitting, isValid, dirty}) => (
            <>
            <div className={styles.stepContent}>
              <div className="field">
                <div className="control is-expanded">
                  <Field type="text" className="input is-large" name="title" placeholder="Project Title..." autoComplete="off" />
                </div>
              </div>
              <ErrorMessage name="title" render={(message) => (
                <p className="help is-danger">{message}</p>
              )} />
              <p className="help">
                A project will typically map to a JMeter test plan, and data files. You could also have more than one JMeter test plan
                in a project, if all your plans need to execute in parallel.
              </p>
            </div>
            <div className="level">
              <div className="level-left">
                <CancelLink {...{dispatch}} />
              </div>
              <div className="level-right">
              {dirty || appState.activeProject === undefined ?
                <button type="submit" className="button is-primary" disabled={isSubmitting || !isValid}>Save &amp; Next</button> :
                <NextLink {...{dispatch}} tab={WizardTabTypes.JMeter} />
              }
              </div>
            </div>
            </>
          )}
        />
      </div>
    </>
  );
}
