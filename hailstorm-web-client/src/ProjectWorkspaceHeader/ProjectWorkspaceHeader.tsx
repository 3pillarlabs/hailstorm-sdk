import React, { useState, useContext } from 'react';
import styles from './ProjectWorkspaceHeader.module.scss';
import { ApiFactory } from '../api';
import { titleCase } from '../helpers';
import { ProjectForm } from '../ProjectConfiguration/ProjectForm';
import { Field, ErrorMessage } from 'formik';
import { AppStateContext } from '../appStateContext';
import { UpdateProjectAction } from '../ProjectWorkspace/actions';
import { AppNotificationContextProps, useNotifications } from '../app-notifications';

export const ProjectWorkspaceHeader: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const notifiers = useNotifications();
  const [isEditable, setEditable] = useState(false);

  if (!appState.activeProject) return null;
  const project = appState.activeProject;

  const toggleEditable = () => setEditable(!isEditable);

  return (
    <div className={`columns ${styles.workspaceHeader}`}>
      <div className="column is-three-quarters">
        {isEditable ?
          textBox({projectId: project.id, title: project.title, dispatch, setEditable, toggleEditable, notifiers}) :
          header({title: project.title, toggleEditable})}
      </div>
      <div className="column">
        {project.running && !project.interimState &&
        <h2 className={`title is-2 ${styles.isStatus}`}>
          <i className={`fas fa-running ${styles.spinnerIcon}`}></i>
          Running
        </h2>}
        {project.interimState &&
        <h2 className={`title is-2 ${styles.isStatus}`}>
          <i className={`fas fa-cog fa-spin ${styles.spinnerIcon}`}></i>
          {titleCase(project.interimState)}...
        </h2>}
      </div>
    </div>
  );
};

function textBox({
  projectId,
  title,
  dispatch,
  setEditable,
  toggleEditable,
  notifiers
}: {
  projectId: number,
  title: string,
  dispatch: React.Dispatch<any>,
  setEditable: React.Dispatch<React.SetStateAction<boolean>>,
  toggleEditable: () => void,
  notifiers: AppNotificationContextProps
}): React.ReactNode {
  const {notifySuccess, notifyError} = notifiers;

  return (
    <ProjectForm
      title={title}
      handleSubmit={(values, _actions) => {
        dispatch(new UpdateProjectAction({title: values.title}));
        setEditable(false);
        ApiFactory()
          .projects()
          .update(projectId, { title: values.title })
          .then(() => notifySuccess(`Updated project title`))
          .catch((reason) => notifyError(`Failed to update project title`, reason));
      }}
      render={({ isSubmitting, isValid }) => (
        <>
          <div className="field is-grouped">
            <div className="control is-expanded">
              <Field name="title" type="text" className="input" />
            </div>
            <div className="control">
              <button
                className="button is-primary"
                disabled={isSubmitting || !isValid}
              >
                Update
              </button>
            </div>
            <div className="control">
              <a className="button" onClick={toggleEditable}>
                <i className="fas fa-times-circle"></i>
              </a>
            </div>
          </div>
          <ErrorMessage
            name="title"
            render={message => <p className="help is-danger">{message}</p>}
          />
        </>
      )}
    />
  );
}

function header({title, toggleEditable}: {title: string, toggleEditable: () => void}) {
  return (
    <h2 className="title is-2">
      {title}
      <sup><a onClick={toggleEditable}><i title="Edit" className={`fas fa-pen ${styles.editTrigger}`}></i></a></sup>
    </h2>
  );
}
