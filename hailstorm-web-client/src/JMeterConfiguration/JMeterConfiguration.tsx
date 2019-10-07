import React, { useContext, useState, useEffect } from 'react';
import { AppStateContext } from '../appStateContext';
import { JMeterSetupCompletedAction } from '../NewProjectWizard/actions';
import { CancelLink, BackLink } from '../NewProjectWizard/WizardControls';
import { WizardTabTypes, JMeterFileUploadState } from "../NewProjectWizard/domain";
import { JMeterPlanList } from './JMeterPlanList';
import { selector } from '../NewProjectWizard/reducer';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { FileUpload } from '../FileUpload';
import { AddJMeterFileAction, CommitJMeterFileAction, AbortJMeterFileUploadAction, MergeJMeterFileAction } from './actions';
import { ApiFactory } from '../api';
import { LocalFile } from '../FileUpload/domain';
import { ValidationNotice } from '../domain';
import { JMeterPropertiesMap } from './JMeterPropertiesMap';

export const JMeterConfiguration: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const state = selector(appState);
  const project = state.activeProject!;
  const handleFileUpload = (file: LocalFile) => {
    ApiFactory()
      .jmeterValidation()
      .create({name: file.name})
      .then((data) => dispatch(new CommitJMeterFileAction({name: file.name, properties: data.properties!})))
      .catch((reason) => {
        if (Object.keys(reason).includes('validationErrors')) {
          const validationErrors = reason['validationErrors'] as ValidationNotice[];
          dispatch(new AbortJMeterFileUploadAction({name: file.name, validationErrors}));
        }
      });
  };

  return (
    <>
    <div className={`level ${styles.stepHeader}`}>
      <div className="level-left">
        <div className="level-item">
          <h3 className="title is-3">{project.title} &mdash; JMeter</h3>
        </div>
      </div>
      <div className="level-right">
        <div className="level-item">
          <FileUpload
            onAccept={(file) => {
              const dataFile: boolean = !file.name.match(/\.jmx$/);
              dispatch(new AddJMeterFileAction({ name: file.name, dataFile }))
            }}
            onFileUpload={handleFileUpload}
            onUploadError={(file, error) => dispatch(new AbortJMeterFileUploadAction({name: file.name, uploadError: error}))}
          >
            <button className="button is-link is-medium" title="Upload .jmx and data files (like .csv)">Upload</button>
          </FileUpload>
        </div>
      </div>
    </div>
    <div className={styles.stepBody}>
      <div className={`columns ${styles.stepContent}`}>
        {!project.jmeter && !appState.wizardState!.activeJMeterFile && (
        <div className="notification is-info">
          There are no test plans or data files yet. You need to upload at least one test plan (.jmx) file.
        </div>
        )}

        {appState.wizardState!.activeJMeterFile && <ActiveJMeterFile file={appState.wizardState!.activeJMeterFile} />}

        <div className="column is-two-fifths">
          {project.jmeter && (<JMeterPlanList {...{dispatch}} jmeter={project.jmeter!} />)}
        </div>

        <div className="column is-three-fifths">
          {
            appState.wizardState!.activeJMeterFile &&
            appState.wizardState!.activeJMeterFile.properties &&
            (<JMeterPropertiesMap
                properties={appState.wizardState!.activeJMeterFile.properties}
                onSubmit={(values, {setSubmitting}) => {
                  setSubmitting(true);
                  const promise = appState.wizardState!.activeJMeterFile!.id === undefined ?
                    ApiFactory()
                      .jmeter()
                      .create(appState.activeProject!.id, {
                        name: appState.wizardState!.activeJMeterFile!.name,
                        properties: new Map(Object.entries(values)),
                        dataFile: appState.wizardState!.activeJMeterFile!.dataFile
                      }) :
                    ApiFactory()
                      .jmeter()
                      .update(
                        appState.activeProject!.id,
                        appState.wizardState!.activeJMeterFile!.id,
                        { properties: new Map(Object.entries(values)) }
                      );

                  promise
                    .then((jmeterFile) => {
                      dispatch(new MergeJMeterFileAction(jmeterFile));
                    })
                    .catch((reason) => console.error(reason))
                    .then(() => setSubmitting(false));
                }}
             />
            )
          }
        </div>
      </div>
      <div className="level">
        <div className="level-left">
          <div className="level-item">
            <CancelLink {...{dispatch}} />
          </div>
          <div className="level-item">
            <BackLink {...{dispatch, tab: WizardTabTypes.Project}} />
          </div>
        </div>
        <div className="level-right">
          <button
            className="button is-primary"
            onClick={() => dispatch(new JMeterSetupCompletedAction())}
            disabled={!project.jmeter || project.jmeter.files.filter((value) => !value.dataFile).length === 0}
          >
            Next
          </button>
        </div>
      </div>
    </div>
    </>
  );
}

function ActiveJMeterFile({file}: {file: JMeterFileUploadState}) {
  if (file.uploadProgress !== undefined && !(file.uploadError || file.validationErrors)) {
    return (
      <div className="notification is-warning">
        Uploading {file.name}...
      </div>
    );
  } else if (file.uploadError) {
    return (
      <div className="notification is-warning">
        Error uploading {file.name}. You should check your set up and try again.
      </div>
    )
  } else if (file.validationErrors) {
    return (
      <>
      {file.validationErrors.map(({type, message}) => (
      <div key={`${type}:${message}`} className={`notification is-${type === 'error' ? 'danger' : type}`}>
        {message}
      </div>
      ))}
      </>
    )
  }

  return null;
}
