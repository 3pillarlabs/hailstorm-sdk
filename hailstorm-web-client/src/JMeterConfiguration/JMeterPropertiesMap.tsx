import React from 'react';
import { Formik, FormikActions, Field, Form, ErrorMessage } from 'formik';
import { FormikActionsHandler } from './domain';

export function JMeterPropertiesMap({
  properties,
  onSubmit,
  onRemove,
  headerTitle
}: {
  properties: Map<string, any>;
  onSubmit?: FormikActionsHandler;
  onRemove?: () => void;
  headerTitle?: string;
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
      {onSubmit && onRemove ? (
      <PropertiesForm {...{properties, onRemove, onSubmit}} />
      ) : (
      <Properties {...{properties}} readOnly={true} />
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
  readOnly
}: {
  properties: Map<string, any>;
  readOnly?: boolean;
}) {
  const readWrite = !readOnly;

  const elements = Array.from(properties.keys()).map((key) => (
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
          value={properties.get(key)}
        />
        )}
      </div>
      {readWrite && (<ErrorMessage name={internalKey(key)} render={(message) => (
        <p className="help is-danger">{message}</p>
      )} />)}
    </div>
  ));

  return (
    <div className="card-content">
      <div className="content">
        {elements}
      </div>
    </div>
  )
}

function PropertiesForm({
  properties,
  onSubmit,
  onRemove
}: {
  properties: Map<string, any>;
  onSubmit: FormikActionsHandler;
  onRemove: () => void;
}) {
  const initialValues: {[key: string]: any} = {};
  for (const [key, value] of properties) {
    initialValues[internalKey(key)] = value || '';
  }

  const isInitialValid = Array.from(properties.values()).every((value) => value !== undefined);
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
    >
    {({isSubmitting, isValid}) => (
      <Form>
        <Properties {...{properties}} />
        <footer className="card-footer">
          <div className="card-footer-item">
            <button type="button" className="button is-warning" onClick={onRemove} role="Remove File">Remove</button>
          </div>
          <div className="card-footer-item">
            <button type="submit" className="button is-dark" disabled={isSubmitting || !isValid}> Save </button>
          </div>
        </footer>
      </Form>
    )}
    </Formik>
  );
}
