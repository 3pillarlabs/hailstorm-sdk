import React, { useState, useEffect } from 'react';
import { ProjectWorkspaceBasicProps } from '../ProjectWorkspace';
import styles from './ProjectWorkspaceHeader.module.scss';
import { ApiFactory } from '../api';
import { titleCase } from '../helpers';
import { ProjectForm } from '../ProjectConfiguration/ProjectForm';
import { Field, ErrorMessage } from 'formik';

export const ProjectWorkspaceHeader: React.FC<ProjectWorkspaceBasicProps> = (props) => {
  const [isEditable, setEditable] = useState(false);
  const [title, setTitle] = useState<string>('');
  const toggleEditable = () => setEditable(!isEditable);

  useEffect(() => {
    console.debug('ProjectWorkspaceHeader#useEffect(props.project)');
    setTitle(props.project.title);
  }, [props.project]);

  return (
    <div className={`columns ${styles.workspaceHeader}`}>
      <div className="column is-three-quarters">
        {isEditable ? textBox(title, setTitle, setEditable, props, toggleEditable) : header(title, toggleEditable)}
      </div>
      <div className="column">
        {props.project.running && !props.project.interimState &&
        <h2 className={`title is-2 ${styles.isStatus}`}>
          <i className={`fas fa-running ${styles.spinnerIcon}`}></i>
          Running
        </h2>}
        {props.project.interimState &&
        <h2 className={`title is-2 ${styles.isStatus}`}>
          <i className={`fas fa-cog fa-spin ${styles.spinnerIcon}`}></i>
          {titleCase(props.project.interimState)}...
        </h2>}
      </div>
    </div>
  );
};

function textBox(
  title: string,
  setTitle: React.Dispatch<React.SetStateAction<string>>,
  setEditable: React.Dispatch<React.SetStateAction<boolean>>,
  props: React.PropsWithChildren<ProjectWorkspaceBasicProps>,
  toggleEditable: () => void
): React.ReactNode {
  return (
    <ProjectForm
      title={title}
      handleSubmit={(values, _actions) => {
        setTitle(values.title!);
        setEditable(false);
        ApiFactory()
          .projects()
          .update(props.project.id, { title: values.title });
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
