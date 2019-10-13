import React from 'react';
import { Formik, FormikActions, Field, Form, ErrorMessage } from 'formik';

export function JMeterPropertiesMap({
  properties,
  onSubmit,
  onRemove,
  headerTitle
}: {
  properties: Map<string, any>;
  onSubmit: (values: {[key: string]: any}, actions: FormikActions<{[key: string]: any}>) => void;
  onRemove: () => void;
  headerTitle?: string;
}) {
  const internalKey = (key: string) => key.replace(/\./g, '-');
  const externalKey = (key: string) => key.replace(/\-/g, '.');
  const initialValues: {[key: string]: any} = {};
  for (const [key, value] of properties) {
    initialValues[internalKey(key)] = value;
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

  const handleSubmit: (values: {[key: string]: any}, actions: FormikActions<{[key: string]: any}>) => void = (values, actions) => {
    const externalValues = Object.entries(values).reduce<{[key: string]: any}>((s, e) => {
      s[externalKey(e[0])] = e[1];
      return s;
    }, {});

    onSubmit(externalValues, actions);
  };

  return (
    <div className="card">
      <header className="card-header">
        {headerTitle ? (
        <p className="card-header-title">{headerTitle}</p>
        ) : null}
      </header>
      <Formik
        {...{initialValues, isInitialValid, onSubmit: handleSubmit, validate}}
      >
      {({isSubmitting, isValid}) => (
        <Form>
          <div className="card-content">
            <div className="content">
            {Array.from(properties.keys()).map((key) => {
              return (
                <div {...{key}} className="field">
                  <label className="label">{key}</label>
                  <div className="control">
                    <Field className="input" type="text" name={internalKey(key)} />
                  </div>
                  <ErrorMessage name={internalKey(key)} render={(message) => (
                    <p className="help is-danger">{message}</p>
                  )} />
                </div>
              );
            })}
            </div>
          </div>
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
    </div>
  );
}
