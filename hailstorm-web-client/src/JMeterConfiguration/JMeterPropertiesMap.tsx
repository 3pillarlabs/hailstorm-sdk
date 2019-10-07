import React from 'react';
import { Formik, FormikActions, Field, Form } from 'formik';

export function JMeterPropertiesMap({
  properties,
  onSubmit
}: {
  properties: Map<string, any>;
  onSubmit: (values: {[key: string]: any}, actions: FormikActions<{[key: string]: any}>) => void;
}) {
  const initialValues: {[key: string]: any} = {};
  for (const [key, value] of properties) {
    initialValues[key] = value;
  }

  const isInitialValid = Array.from(properties.values()).every((value) => value !== undefined);
  const validate: (values: {[key: string]: any}) => {[key: string]: string} = (values) => {
    const errors: {[key: string]: string} = {};
    Object.entries(values).forEach(([key, value]) => {
      if (value === undefined || value.toString().trim().length === 0) {
        errors[key] = `${key} can't be blank`;
      }
    });

    return errors;
  }

  return (
    <Formik
      {...{initialValues, isInitialValid, onSubmit, validate}}
    >
    {({isSubmitting, isValid}) => (
      <Form>
      {Array.from(properties.keys()).map((key) => (
        <div {...{key}} className="field is-horizontal">
          <div className="field-label">
            <label className="label">{key}</label>
          </div>
          <div className="field-body">
            <div className="field">
              <div className="control">
                <Field className="input" type="text" name={key} />
              </div>
            </div>
          </div>
        </div>
      ))}
        <div className="field is-horizontal">
          <div className="field-label">
          </div>
          <div className="field-body">
            <div className="field">
              <div className="control">
                <button className="button is-primary" disabled={isSubmitting || !isValid}> Save </button>
              </div>
            </div>
          </div>
        </div>
      </Form>
    )}
    </Formik>
  );
}
