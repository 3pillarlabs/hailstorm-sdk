import React, { useEffect, useContext, useState } from 'react';
import { ProjectWorkspaceHeader } from '../ProjectWorkspaceHeader';
import { ProjectWorkspaceMain } from '../ProjectWorkspaceMain';
import { ProjectWorkspaceLog } from '../ProjectWorkspaceLog';
import { ProjectWorkspaceFooter } from '../ProjectWorkspaceFooter';
import { Project } from '../domain';
import { ApiFactory } from '../api';
import { Loader, LoaderSize } from '../Loader';
import { RouteComponentProps, Prompt, Redirect } from 'react-router';
import { SetProjectAction } from './actions';
import { AppStateContext } from '../appStateContext';
import { Modal } from '../Modal';
import { Location } from 'history';

export interface ProjectWorkspaceBasicProps {
  project: Project;
}

const CONFIRM_DELAY_MS = 3000;

export const ProjectWorkspace: React.FC<RouteComponentProps<{ id: string }>> = (props) => {
  const {appState, dispatch} = useContext(AppStateContext);
  const project = appState.activeProject;
  const [showModal, setShowModal] = useState(false);
  const [nextLocation, setNextLocation] = useState<Location>();
  const [shouldRedirect, setShouldRedirect] = useState(false);
  const [confirmDisabled, setConfirmDisabled] = useState(true);

  const navAwayHandler = (location: Location<any>) => {
    if (!shouldRedirect) {
      setShowModal(true);
      setTimeout(() => setConfirmDisabled(!confirmDisabled), CONFIRM_DELAY_MS);
    }

    setNextLocation(location);
    return shouldRedirect;
  };

  const modalConfirmHandler = () => {
    setShowModal(false);
    setShouldRedirect(true);
  }

  const modalCancelHandler = () => {
    setShowModal(false);
    setConfirmDisabled(!confirmDisabled);
  }

  useEffect(() => {
    console.debug('ProjectWorkspace#useEffect(props)');
    if (props.location.state) {
      dispatch(new SetProjectAction(props.location.state.project));
    } else {
      ApiFactory()
        .projects()
        .get(parseInt(props.match.params.id))
        .then((fetchedProject) => dispatch(new SetProjectAction(fetchedProject)));
    }
  }, [props.match.params.id]);

  useEffect(() => {
    const listener = function(ev: BeforeUnloadEvent) {
      if (project && project.interimState !== undefined) {
        ev.preventDefault();
        ev.returnValue = false;
      } else {
        delete ev['returnValue'];
      }
    };

    window.addEventListener('beforeunload', listener);

    return () => {
      window.removeEventListener('beforeunload', listener);
    };
  }, [project]);

  return (
    <div className="container">
    {project && project.id === parseInt(props.match.params.id) ?
      <>
      <Prompt when={project.interimState !== undefined} message={(nextLocation) => navAwayHandler(nextLocation)} />
      <Modal isActive={showModal}>
        <div className={`modal${showModal ? " is-active" : ""}`}>
          <div className="modal-background"></div>
          <div className="modal-content">
            <article className="message is-danger">
              <div className="message-body">
                <p>
                  You have operations in progress. If you navigate away from this page now, the operations will
                  terminate, leaving the system in an ambigious state. You will most likely have to terminate
                  the setup and start over again.
                </p>
                <p>
                  <strong>Are you sure you want to navigate away from the page?</strong>
                </p>
                <div className="field is-grouped is-grouped-centered">
                  <p className="control">
                    <a className="button is-primary" onClick={modalCancelHandler}>No, Cancel</a>
                  </p>
                  <p className="control">
                    <button disabled={confirmDisabled} className="button is-danger" onClick={modalConfirmHandler}>
                      Yes, I'm sure
                    </button>
                  </p>
                </div>
              </div>
            </article>
          </div>
        </div>
      </Modal>
      {shouldRedirect &&
        <Redirect to={nextLocation!} />}
      <ProjectWorkspaceHeader project={project} />
      <ProjectWorkspaceMain />
      <ProjectWorkspaceLog />
      <ProjectWorkspaceFooter />
      {props.children}
      </>
      :
      <Loader size={LoaderSize.APP} />}
    </div>
  );
}
