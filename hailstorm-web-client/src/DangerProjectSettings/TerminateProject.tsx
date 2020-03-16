import React, { useContext, useState } from 'react';
import { InterimProjectState } from '../domain';
import { SetInterimStateAction, UnsetInterimStateAction, SetRunningAction } from '../ProjectWorkspace/actions';
import { ApiFactory } from '../api';
import { Modal } from '../Modal/Modal';
import styles from './DangerProjectSettings.module.scss';
import { AppStateContext } from '../appStateContext';

export const TerminateProject: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const project = appState.activeProject!;
  const [showModal, setShowModal] = useState(false);
  const [isUnderstood, setIsUnderstood] = useState(false);
  const handleTerminate = () => {
    setShowModal(false);
    dispatch(new SetInterimStateAction(InterimProjectState.TERMINATING));
    ApiFactory()
      .projects()
      .update(project.id, {action: 'terminate'})
      .then(() => dispatch(new UnsetInterimStateAction()))
      .then(() => dispatch(new SetRunningAction(false)));
  }

  return (
    <div className="message-body">
      <div className="columns">
        <div className="column is-3">
          <button
            className="button is-warning"
            onClick={() => setShowModal(true)}
            disabled={project.interimState && project.interimState === InterimProjectState.TERMINATING}
          >
            <i className="fas fa-bomb"></i>&nbsp; Terminate this project
          </button>
        </div>
        <div className="column is-9">
          <article>
            <p>
              If you terminate this project, your set up for running tests will be removed. You may want
              to terminate in the following situations -
            </p>
            <ul>
              <li key="line-1">A diagnostic message from the application asked you.</li>
              <li key="line-2">If you want to save cloud costs during periods of inactivity.</li>
            </ul>
          </article>
        </div>
      </div>
      <Modal isActive={showModal}>
        <div className={`modal${showModal ? " is-active" : ""} ${styles.modal}`}>
          <div className="modal-background"></div>
          <div className="modal-content">
            <article className="message is-warning">
              <div className="message-body">
                {project.running || project.interimState ? (
                <p className="notification is-danger">
                  <label>
                    <input type="checkbox" checked={isUnderstood} onChange={() => setIsUnderstood(!isUnderstood)} />
                    I understand that I have tests or operations in progress, and I will lose data if I
                    terminate now.
                  </label>
                </p>
                ): null}
                <p>
                  This action can't be stopped mid-way, and the next test will take longer to start.
                </p>
                <p>
                  Are you sure you want to terminate the setup?
                </p>
                <div className="field is-grouped is-grouped-centered">
                  <p className="control">
                    <a className="button is-primary" onClick={() => setShowModal(false)}>No, Cancel</a>
                  </p>
                  <p className="control">
                    <button
                      className="button is-danger"
                      disabled={(project.running || project.interimState) && !isUnderstood}
                      onClick={handleTerminate}
                    >
                      Yes, Terminate
                    </button>
                  </p>
                </div>
              </div>
            </article>
          </div>
        </div>
      </Modal>
    </div>
  );
};
