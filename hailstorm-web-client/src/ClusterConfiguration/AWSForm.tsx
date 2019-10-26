import React, { useState } from 'react';
import { Project } from '../domain';
import { RemoveClusterAction, SaveClusterAction } from './actions';
import { Formik, Field, Form, FormikActions, ErrorMessage } from 'formik';
import { AWSInstanceChoice } from './AWSInstanceChoice';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { ApiFactory } from '../api';
import { AWSRegionChoice } from './AWSRegionChoice';

export function AWSForm({ dispatch, activeProject }: {
  dispatch: React.Dispatch<any>;
  activeProject: Project;
}) {
  const [hourlyCostByCluster, setHourlyCostByCluster] = useState<number>();
  const [awsRegion, setAwsRegion] = useState<string>();
  const [selectedInstanceType, setSelectedInstanceType] = useState<AWSInstanceChoiceOption>();
  const fetchRegions: () => Promise<AWSRegionList> = () => {
    return ApiFactory().awsRegion().list();
  };

  const fetchPricing: (regionCode: string) => Promise<AWSInstanceChoiceOption[]> = (regionCode) => {
    return ApiFactory().awsInstancePricing().list(regionCode);
  };

  const handleAWSInstanceChange = (value: AWSInstanceChoiceOption) => {
    setSelectedInstanceType(value);
    if (value.hourlyCostByInstance > 0) {
      setHourlyCostByCluster(value.hourlyCostByCluster());
    }
  };

  const handleSubmit = (values: {
    accessKey: string;
    secretKey: string;
    vpcSubnetId?: string;
  }, actions: FormikActions<{
    accessKey: string;
    secretKey: string;
    vpcSubnetId?: string;
  }>) => {
    actions.setSubmitting(true);
    ApiFactory()
      .clusters()
      .create(activeProject.id, {
        ...values,
        type: 'AWS',
        title: '',
        region: awsRegion!,
        instanceType: selectedInstanceType!.instanceType,
        maxThreadsByInstance: selectedInstanceType!.maxThreadsByInstance
      })
      .then((createdCluster) => dispatch(new SaveClusterAction(createdCluster)))
      .catch((reason) => console.error(reason))
      .finally(() => actions.setSubmitting(false));
  };

  return (
    <div className="card">
      <div className="card-header">
        <div className="card-header-title">
          <span className="icon"><i className="fab fa-aws"></i></span>
          Create a new AWS Cluster
        </div>
      </div>
      <Formik
        isInitialValid={false}
        initialValues={{
          accessKey: '',
          secretKey: '',
          vpcSubnetId: ''
        }}
        validate={(values) => {
          const errors: {
            accessKey?: string;
            secretKey?: string;
          } = {};
          if (!values.accessKey) {
            errors.accessKey = "AWS Access Key can't be blank";
          }

          if (!values.secretKey) {
            errors.secretKey = "AWS Secret Key can't be blank";
          }

          return errors;
        }}
        onSubmit={(values, actions) => handleSubmit(values, actions)}
      >
        {({ isSubmitting, isValid }) => (
        <Form data-testid="AWSForm">
          <div className="card-content">
            <div className="field">
              <label className="label">AWS Access Key *</label>
              <div className="control">
                <Field required name="accessKey" className="input" type="text" data-testid="AWS Access Key" disabled={isSubmitting} />
              </div>
              <ErrorMessage name="accessKey" render={(message) => (<p className="help is-danger">{message}</p>)} />
            </div>
            <div className="field">
              <label className="label">AWS Secret Key *</label>
              <div className="control">
                <Field required name="secretKey" className="input" type="password" data-testid="AWS Secret Key" disabled={isSubmitting} />
              </div>
              <ErrorMessage name="secretKey" render={(message) => (<p className="help is-danger">{message}</p>)} />
            </div>
            <div className="field">
              <label className="label">VPC Subnet</label>
              <div className="control">
                <Field name="vpcSubnetId" className="input" type="text" data-testid="VPC Subnet" disabled={isSubmitting} />
              </div>
            </div>
            <div className="field">
              <label className="label">AWS Region *</label>
              <div className="control">
                <AWSRegionChoice onAWSRegionChange={setAwsRegion} {...{ fetchRegions }} disabled={isSubmitting} />
              </div>
            </div>
            {awsRegion ? (<>
              <div className="field">
                <div className="control">
                  <AWSInstanceChoice
                    onChange={handleAWSInstanceChange}
                    regionCode={awsRegion}
                    {...{ fetchPricing, setHourlyCostByCluster }}
                    disabled={isSubmitting}
                  />
                </div>
              </div>
              <div className="field">
                {hourlyCostByCluster ? (
                <div className="message is-info">
                  <div className="message-body">
                    <strong>Estimated Hourly Cost for the Cluster: ${hourlyCostByCluster.toFixed(4)}</strong>
                  </div>
                </div>) : null}
              </div>
            </>) : null}
          </div>
          <div className="card-footer">
            <div className="card-footer-item">
              <button type="button" className="button is-warning" role="Remove Cluster" onClick={() => dispatch(new RemoveClusterAction())}>
                Remove
              </button>
            </div>
            <div className="card-footer-item">
              <button type="submit" className="button is-dark" disabled={isSubmitting || !isValid}>Save</button>
            </div>
          </div>
        </Form>)}
      </Formik>
    </div>
  );
}
