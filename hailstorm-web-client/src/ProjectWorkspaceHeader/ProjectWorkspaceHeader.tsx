import React, { useState, useContext, useEffect } from 'react';
import { ProjectWorkspaceBasicProps } from '../ProjectWorkspace';
import styles from './ProjectWorkspaceHeader.module.scss';
import { ApiFactory } from '../api';
import { RunningProjectsContext } from '../RunningProjectsProvider';

export const ProjectWorkspaceHeader: React.FC<ProjectWorkspaceBasicProps> = (props) => {
  const [isEditable, setEditable] = useState(false);
  const [title, setTitle] = useState<string>('');
  const [errorMessage, setErrorMessage] = useState<string>('');
  const toggleEditable = () => setEditable(!isEditable);
  let inputRef = React.createRef<any>();
  const {reloadRunningProjects} = useContext(RunningProjectsContext);
  const onSubmitHandler = () => {
    const inputValue = inputRef.current.value as string;
    console.debug(inputValue);
    if (inputValue.trim().length === 0) {
      setErrorMessage("Title can't be blank");
      return;
    }

    setTitle(inputValue);
    setEditable(false);
    ApiFactory()
      .projects()
      .update(props.project.id, {title: inputRef.current.value})
      .then(() => {
        if (props.project.running) reloadRunningProjects();
      });
  };

  useEffect(() => {
    setTitle(props.project.title);
  }, [props]);

  return (
    <div className="columns workspace-header">
      <div className="column is-four-fifths">
        {isEditable ? textBox({title, onSubmitHandler, inputRef, toggleEditable, errorMessage}) : header(title, toggleEditable)}
      </div>
      <div className="column">
        {props.project.running && <h2 className="title is-2 is-status">Running</h2>}
      </div>
    </div>
  );
};

function textBox({
    title,
    onSubmitHandler,
    inputRef,
    toggleEditable,
    errorMessage
  }: {
        title: string,
        onSubmitHandler: () => void,
        inputRef: React.RefObject<any>,
        toggleEditable: () => void,
        errorMessage: string
      }
  ) {
  return (
    <form onSubmit={onSubmitHandler}>
      <div className="field is-grouped">
        <div className="control is-expanded">
          <input defaultValue={title} type="text" className="input" ref={inputRef} />
        </div>
        <div className="control">
          <button className="button is-primary">Update</button>
        </div>
        <div className="control">
          <a className="button" onClick={toggleEditable}><i className="fas fa-times-circle"></i></a>
        </div>
      </div>
      {errorMessage && <p className="help is-danger">{errorMessage}</p>}
    </form>
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
