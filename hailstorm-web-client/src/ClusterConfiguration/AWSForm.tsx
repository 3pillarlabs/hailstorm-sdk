import React, { useState } from 'react';
import { Project } from '../domain';
import { RemoveClusterAction, CreateClusterAction } from './actions';
import { Formik, Field, Form, FormikActions, ErrorMessage } from 'formik';
import { AWSInstanceChoice } from './AWSInstanceChoice';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { ApiFactory } from '../api';
import { AWSRegionChoice } from './AWSRegionChoice';
import { ClusterFormFooter } from './ClusterFormFooter';
import { ClusterViewHeader } from './ClusterViewHeader';

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

  const handleAWSInstanceChange = (choice: AWSInstanceChoiceOption) => {
    setSelectedInstanceType(choice);
    if (choice.hourlyCostByInstance > 0) {
      setHourlyCostByCluster(choice.hourlyCostByCluster());
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
      .then((createdCluster) => dispatch(new CreateClusterAction(createdCluster)))
      .catch((reason) => console.error(reason))
      .finally(() => actions.setSubmitting(false));
  };

  return (
    <div className="card">
      <ClusterViewHeader
        title="Create a new AWS Cluster"
        icon={(<i className="fab fa-aws"></i>)}
      />
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
                    {...{ fetchPricing, setHourlyCostByCluster, hourlyCostByCluster }}
                    disabled={isSubmitting}
                  />
                </div>
              </div>
            </>) : null}
          </div>
          <ClusterFormFooter {...{dispatch}} disabled={isSubmitting || !isValid} />
        </Form>)}
      </Formik>
    </div>
  );
}
