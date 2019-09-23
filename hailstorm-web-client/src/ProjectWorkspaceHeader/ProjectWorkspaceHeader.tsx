import React, { useState, useContext } from 'react';
import styles from './ProjectWorkspaceHeader.module.scss';
import { ApiFactory } from '../api';
import { titleCase } from '../helpers';
import { ProjectForm } from '../ProjectConfiguration/ProjectForm';
import { Field, ErrorMessage } from 'formik';
import { AppStateContext } from '../appStateContext';
import { UpdateProjectAction } from '../ProjectWorkspace/actions';

export const ProjectWorkspaceHeader: React.FC = () => {
  const {appState, dispatch} = useContext(AppStateContext);
  const [isEditable, setEditable] = useState(false);

  if (!appState.activeProject) return null;
  const project = appState.activeProject;

  const toggleEditable = () => setEditable(!isEditable);

  return (
    <div className={`columns ${styles.workspaceHeader}`}>
      <div className="column is-three-quarters">
        {isEditable ?
          textBox(project.id, project.title, dispatch, setEditable, toggleEditable) :
          header(project.title, toggleEditable)}
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

function textBox(
  projectId: number,
  title: string,
  dispatch: React.Dispatch<any>,
  setEditable: React.Dispatch<React.SetStateAction<boolean>>,
  toggleEditable: () => void
): React.ReactNode {
  return (
    <ProjectForm
      title={title}
      handleSubmit={(values, _actions) => {
        dispatch(new UpdateProjectAction({title: values.title}));
        setEditable(false);
        ApiFactory()
          .projects()
          .update(projectId, { title: values.title });
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

function header(value: string, toggleEditable: () => void) {
  return (
    <h2 className="title is-2">
      {value}
      <sup><a onClick={toggleEditable}><i title="Edit" className={`fas fa-pen ${styles.editTrigger}`}></i></a></sup>
    </h2>
  );
}
