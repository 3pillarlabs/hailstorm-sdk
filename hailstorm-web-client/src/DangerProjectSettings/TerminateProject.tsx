import React, { useContext, useState } from 'react';
import { InterimProjectState, Project } from '../domain';
import { SetInterimStateAction, UnsetInterimStateAction, SetRunningAction, UpdateProjectAction } from '../ProjectWorkspace/actions';
import { ApiFactory } from '../api';
import { Modal } from '../Modal/Modal';
import styles from './DangerProjectSettings.module.scss';
import { AppStateContext } from '../appStateContext';


function TerminateButton({
  setShowModal,
  project
}:{
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  project: Project;
}) {
  return (
    <button
    className="button is-warning"
    onClick={() => setShowModal(true)}
    disabled={project.interimState && project.interimState === InterimProjectState.TERMINATING}
  >
    <i className="fas fa-bomb"></i>&nbsp; Terminate this project
  </button>
  );
}

function ConfirmModal({
  showModal,
  setShowModal,
  project,
  isUnderstood,
  setIsUnderstood,
  handleTerminate
}:{
  showModal: boolean;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  project: Project;
  isUnderstood: boolean;
  setIsUnderstood: React.Dispatch<React.SetStateAction<boolean>>;
  handleTerminate: () => void;
}) {
  return (
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
  );
}

function TwoColumn({
  showModal,
  setShowModal,
  project,
  isUnderstood,
  setIsUnderstood,
  handleTerminate
}:{
  showModal: boolean;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  project: Project;
  isUnderstood: boolean;
  setIsUnderstood: React.Dispatch<React.SetStateAction<boolean>>;
  handleTerminate: () => void;
}) {
  return (
    <>
      <div className="columns">
        <div className="column is-3">
          <TerminateButton {...{setShowModal, project}} />
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
      <ConfirmModal {...{showModal, setShowModal, project, isUnderstood, setIsUnderstood, handleTerminate}} />
    </>
  );
}

function SingleColumn({
  showModal,
  setShowModal,
  project,
  isUnderstood,
  setIsUnderstood,
  handleTerminate
}:{
  showModal: boolean;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  project: Project;
  isUnderstood: boolean;
  setIsUnderstood: React.Dispatch<React.SetStateAction<boolean>>;
  handleTerminate: () => void;
}) {
  return (
    <p>
      <p className="has-text-left">
        <TerminateButton {...{setShowModal, project}} />
      </p>
      <br/>
      <p className="has-text-left">
        Terminate project to save cloud costs after testing.
      </p>
      <ConfirmModal {...{showModal, setShowModal, project, isUnderstood, setIsUnderstood, handleTerminate}} />
    </p>
  );
}

export const TerminateProject: React.FC<{
  display?: 'TwoColumn' | 'SingleColumn'
}> = ({
  display
}) => {
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
      .then(() => dispatch(new SetRunningAction(false)))
      .then(() => ApiFactory().projects().get(project.id))
      .then((project) => dispatch(new UpdateProjectAction(project)));
  }

  return (
    <div className="message-body">
      {(display === undefined || display === 'TwoColumn') &&
      <TwoColumn {...{project, showModal, setShowModal, isUnderstood, setIsUnderstood, handleTerminate}} />
      }
      {display === 'SingleColumn' &&
      <SingleColumn {...{project, showModal, setShowModal, isUnderstood, setIsUnderstood, handleTerminate}} />}
    </div>
  );
};

export function highlightTerminate(project: Project): boolean {
  return (
    (!project.running && project.live) ||
    project.interimState === InterimProjectState.TERMINATING
  );
}
