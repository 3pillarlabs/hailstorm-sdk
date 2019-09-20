import React from 'react';
import { Formik, FormikActions, Form, FormikProps } from 'formik';
import { Project } from '../domain';

type ProjectAttributes = {[K in keyof Project]?: Project[K]};

export interface ProjectFormProps {
  title: string;
  handleSubmit: (values: ProjectAttributes, actions: FormikActions<ProjectAttributes>) => void;
  render: (props: FormikProps<ProjectAttributes>) => React.ReactNode;
};

export const ProjectForm: React.FC<ProjectFormProps> = ({title, handleSubmit, render}) => (
  <Formik
    initialValues={{title}}
    validate={(values) => {
      const errors: {title?: string} = {};
      if (!values.title.trim()) {
        errors.title = "Title can't be blank";
      }

      return errors;
    }}
    onSubmit={(values, actions) => handleSubmit(values, actions)}
  >
  {(renderProps) => (
    <Form>
      {render(renderProps)}
    </Form>
  )}
  </Formik>
);
