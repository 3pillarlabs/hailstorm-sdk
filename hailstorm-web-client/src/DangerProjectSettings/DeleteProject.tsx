import React, { useContext, useState } from 'react';
import { Modal } from '../Modal';
import { SetInterimStateAction, UnsetInterimStateAction } from '../ProjectWorkspace/actions';
import { InterimProjectState } from '../domain';
import { ApiFactory } from '../api';
import styles from './DangerProjectSettings.module.scss';
import { Redirect } from 'react-router';
import { AppStateContext } from '../appStateContext';
import { SetProjectDeletedAction } from '../NewProjectWizard/actions';
import { ModalConfirmation } from '../Modal/ModalConfirmation';
import { ModalPrompt } from '../Modal/ModalPrompt';

const REDIRECT_DELAY_MS: number = 3000;

export const DeleteProject: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const project = appState.activeProject!;
  const [showModal, setShowModal] = useState(false);
  const [showRedirectNotice, setShowRedirectNotice] = useState(false);
  const [doRedirect, setDoRedirect] = useState(false);
  const handleDelete = () => {
    setShowModal(false);
    dispatch(new SetInterimStateAction(InterimProjectState.DELETING));
    let firstPromise: Promise<number>;
    if ((project.jmeter && project.jmeter.files.length > 0) || (project.clusters && project.clusters.length > 0)) {
      firstPromise = ApiFactory().projects().update(project.id, {action: 'terminate'});
    } else {
      firstPromise = Promise.resolve(200);
    }

    firstPromise
      .then(() => dispatch(new UnsetInterimStateAction()))
      .then(() => ApiFactory().projects().delete(project.id))
      .then(() => {
        setShowRedirectNotice(true);
        setShowModal(true);
        setTimeout(() => {
          setDoRedirect(true);
          dispatch(new SetProjectDeletedAction());
        }, REDIRECT_DELAY_MS);
      });
  };

  return (
    <div className="message-body">
      <div className="columns">
        <div className="column is-3">
          <button
            className="button is-danger"
            disabled={project.running || project.interimState !== undefined}
            onClick={() => setShowModal(true)}
          >
            <i className="fas fa-trash"></i>&nbsp; Delete this project
          </button>
        </div>
        <div className="column is-9">
          <article>
            <p>
              If you delete this project, you will lose all configuration (JMeter, Cluster) and resources.
              You will not be able to run the tests again. This action <strong>permanently deletes all data</strong>.
              Please ensure:
            </p>
            <ul>
              <li key="line-1">Data you need is exported.</li>
              <li key="line-2">There are no on-going operations.</li>
              <li key="line-3">If you want to delete the project while there are on-going operations, terminate the project first.</li>
            </ul>
          </article>
        </div>
      </div>
      {doRedirect && <Redirect to='/' />}
      <Modal isActive={showModal}>
      {!showRedirectNotice ? (
        <ModalConfirmation
          cancelHandler={() => setShowModal(false)}
          confirmHandler={handleDelete}
          isActive={showModal}
          cancelButtonLabel="No, Cancel"
          confirmButtonLabel="Yes, Delete"
          classModifiers={styles.modal}
        >
        <>
          <p>
            <strong>
              This will permanently delete all configuration and data from the application.
            </strong>
          </p>
          <p>
            Are you sure you want to delete the project?
          </p>
        </>
        </ModalConfirmation>
      ) : (
        <ModalPrompt
          isActive={showModal}
          classModifiers={styles.modal}
        >
          <div className="notification is-success">
            <p className="is-size-5">
              <i className="fas fa-check-circle"></i>
              Project was successfully deleted, redirecting to project list...
            </p>
          </div>
        </ModalPrompt>
      )}
      </Modal>
    </div>
  )
};
