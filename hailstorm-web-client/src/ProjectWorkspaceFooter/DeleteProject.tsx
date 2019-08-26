import React, { useContext, useState } from 'react';
import { Modal } from '../Modal';
import { SetInterimStateAction, UnsetInterimStateAction } from '../ProjectWorkspace/actions';
import { InterimProjectState } from '../domain';
import { ApiFactory } from '../api';
import styles from './ProjectWorkspaceFooter.module.scss';
import { Redirect } from 'react-router';
import { AppStateContext } from '../appStateContext';

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
    ApiFactory()
      .projects()
      .update(project.id, {action: 'terminate'})
      .then(() => dispatch(new UnsetInterimStateAction()))
      .then(() => ApiFactory().projects().delete(project.id))
      .then(() => {
        setShowRedirectNotice(true);
        setShowModal(true);
        setTimeout(() => setDoRedirect(true), REDIRECT_DELAY_MS);
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
        <div className={`modal${showModal ? " is-active" : ""} ${styles.modal}`}>
          <div className="modal-background"></div>
          <div className="modal-content">
            <article className={`message ${showRedirectNotice ? 'is-success' : 'is-danger'}`}>
              <div className="message-body">
                {!showRedirectNotice ? (
                <>
                <p>
                  <strong>
                    This will permanently delete all configuration and data from the application.
                  </strong>
                </p>
                <p>
                  Are you sure you want to delete the project?
                </p>
                <div className="field is-grouped is-grouped-centered">
                  <p className="control">
                    <a className="button is-primary" onClick={() => setShowModal(false)}>No, Cancel</a>
                  </p>
                  <p className="control">
                    <button className="button is-danger" onClick={handleDelete}>Yes, Delete</button>
                  </p>
                </div>
                </>
                ) : (
                <div className="notification is-success">
                  <p className="is-size-5">
                    <i className="fas fa-check-circle"></i>
                    Project was successfully deleted, redirecting to project list...
                  </p>
                </div>
                )}
              </div>
            </article>
          </div>
        </div>
      </Modal>
    </div>
  )
};
