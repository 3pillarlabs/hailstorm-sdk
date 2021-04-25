import React from 'react';
import { Formik, Field, Form, ErrorMessage } from 'formik';
import { FormikActionsHandler } from './domain';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';

export function JMeterPropertiesMap({
  properties,
  onSubmit,
  onRemove,
  headerTitle,
  planExecutedBefore,
  toggleDisabled,
  disabled,
  fileId
}: {
  properties: {key: string, value: any}[];
  onSubmit?: FormikActionsHandler;
  onRemove?: () => void;
  headerTitle?: string;
  planExecutedBefore?: boolean;
  toggleDisabled?: (disabled: boolean) => void;
  disabled?: boolean;
  fileId: number | undefined;
}) {

  return (
    <div className="card">
      <header className="card-header">
        {headerTitle ? (
        <p className="card-header-title">
          <span className="icon">
            <i className="fas fa-feather-alt"></i>
          </span>
          {headerTitle}
        </p>
        ) : null}
      </header>
      {onSubmit && onRemove && !disabled ? (
      <PropertiesForm
        {...{properties, onRemove, onSubmit, planExecutedBefore, fileId}}
        onDisable={() => !!toggleDisabled && toggleDisabled(true)}
      />
      ) : (
      <Properties
        {...{properties, onRemove, disabled, planExecutedBefore}}
        readOnly={true}
        onEnable={() => !!toggleDisabled && toggleDisabled(false)}
      />
      )}
    </div>
  );
}

function internalKey(key: string) {
  return key.replace(/\./g, '-');
}

function externalKey(key: string) {
  return key.replace(/\-/g, '.');
}

function Properties({
  properties,
  readOnly,
  disabled,
  onEnable,
  planExecutedBefore,
  onRemove
}: {
  properties: {key: string, value: any}[];
  readOnly?: boolean;
  disabled?: boolean;
  onEnable?: () => void;
  planExecutedBefore?: boolean;
  onRemove?: () => void;
}) {
  const readWrite = !readOnly;

  const elements = properties.map(({key, value}) => (
    <div {...{key}} className="field">
      <label className="label">{key}</label>
      <div className="control">
        {readWrite ? (
        <Field className="input" type="text" name={internalKey(key)} data-testid={key} />
        ) : (
        <input
          readOnly
          className="input is-static has-background-light has-text-dark is-size-5"
          type="text"
          name={internalKey(key)}
          {...{value}}
        />
        )}
      </div>
      {readWrite && (<ErrorMessage name={internalKey(key)} render={(message) => (
        <p className="help is-danger">{message}</p>
      )} />)}
    </div>
  ));

  return (
    <>
    <div className={`card-content${disabled ? ` ${styles.disabledContent}` : ''}`}>
      <div className="content">
        {elements}
      </div>
    </div>
    {disabled && (
    <footer className="card-footer">
      {!planExecutedBefore && (
      <div className="card-footer-item">
        <button type="button" className="button is-warning" onClick={onRemove} role="Remove File">Remove</button>
      </div>)}
      <div className="card-footer-item">
        <button type="button" className="button is-primary" role="Enable Plan" onClick={onEnable}>Enable</button>
      </div>
    </footer>)}
    </>
  )
}

export function PropertiesForm({
  properties,
  onSubmit,
  onRemove,
  planExecutedBefore,
  onDisable,
  fileId
}: {
  properties: {key: string, value: any}[];
  onSubmit: FormikActionsHandler;
  onRemove: () => void;
  planExecutedBefore?: boolean;
  onDisable: () => void;
  fileId: number | undefined;
}) {
  const initialValues: {[key: string]: any} = {};
  for (const {key, value} of properties) {
    initialValues[internalKey(key)] = value || '';
  }

  const isInitialValid = properties.every(({key, value}) => value !== undefined);
  const validate: (values: {[key: string]: any}) => {[key: string]: string} = (values) => {
    const errors: {[key: string]: string} = {};
    Object.entries(values).forEach(([key, value]) => {
      if (value === undefined || value.toString().trim().length === 0) {
        errors[key] = `${externalKey(key)} can't be blank`;
      }
    });

    return errors;
  }

  const handleSubmit: FormikActionsHandler = (values, actions) => {
    const externalValues = Object.entries(values).reduce<{[key: string]: any}>((s, e) => {
      s[externalKey(e[0])] = e[1];
      return s;
    }, {});

    onSubmit(externalValues, actions);
  };

  return (
    <Formik
      {...{initialValues, isInitialValid, onSubmit: handleSubmit, validate}}
      enableReinitialize={true}
    >
    {({isSubmitting, isValid, dirty}) => (
      <Form>
        <Properties {...{properties}} />
        <footer className="card-footer">
          {!planExecutedBefore && (
          <div className="card-footer-item">
            <button type="button" className="button is-warning" onClick={onRemove} role="Remove File">Remove</button>
          </div>)}
          {!!fileId && (
          <div className="card-footer-item">
            <button type="button" className="button is-warning" onClick={onDisable} role="Disable File">Disable</button>
          </div>)}
          <div className="card-footer-item">
            <button type="submit" className="button is-dark" disabled={isSubmitting || !isValid || !dirty}> Save </button>
          </div>
        </footer>
      </Form>
    )}
    </Formik>
  );
}
