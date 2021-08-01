import React, { useState } from 'react';
import { Project } from '../domain';
import { CreateClusterAction } from './actions';
import { Formik, Field, Form, FormikActions, ErrorMessage } from 'formik';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { ApiFactory } from '../api';
import { AWSRegionChoice } from './AWSRegionChoice';
import { ClusterFormFooter } from './ClusterFormFooter';
import { ClusterViewHeader } from './ClusterViewHeader';
import { useNotifications } from '../app-notifications';
import { AWSFormField, AWSInstanceChoiceField } from './AWSFormField';

export function AWSForm({ dispatch, activeProject }: {
  dispatch: React.Dispatch<any>;
  activeProject: Project;
}) {
  const [awsRegion, setAwsRegion] = useState<string>();
  const [selectedInstanceType, setSelectedInstanceType] = useState<AWSInstanceChoiceOption>();
  const [baseAMI, setBaseAMI] = useState<string>();
  const {notifySuccess, notifyError} = useNotifications();
  const fetchRegions: () => Promise<AWSRegionList> = () => {
    return ApiFactory().awsRegion().list();
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
        maxThreadsByInstance: selectedInstanceType!.maxThreadsByInstance,
        baseAMI: baseAMI
      })
      .then((createdCluster) => {
        dispatch(new CreateClusterAction(createdCluster));
        notifySuccess(`Saved ${createdCluster.title} cluster configuration`);
      })
      .catch((reason) => notifyError(`Failed to save the AWS ${awsRegion} cluster configuration`, reason))
      .finally(() => actions.setSubmitting(false));
  };

  const onAWSRegionChange: (
    region: string,
    options?: {
      baseAMI?: string;
    }
  ) => void = (region, options) => {
    setAwsRegion(region);
    if (options) {
      setBaseAMI(options.baseAMI);
    }
  };

  const validateInputs = (values: {accessKey: string, secretKey: string}) => {
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
        validate={validateInputs}
        onSubmit={(values, actions) => handleSubmit(values, actions)}
      >
        {({ isSubmitting, isValid }) => (
        <Form data-testid="AWSForm">
          <div className="card-content">
            <AWSFormField
              labelText="AWS Access Key"
              required={true}
              disabled={isSubmitting}
              fieldName="accessKey"
            />
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
                <AWSRegionChoice {...{fetchRegions, onAWSRegionChange}} disabled={isSubmitting} />
              </div>
            </div>
            {awsRegion && (
            <AWSInstanceChoiceField {...{awsRegion, setSelectedInstanceType}} disabled={isSubmitting} />
            )}
          </div>
          <ClusterFormFooter {...{dispatch}} disabled={isSubmitting || !isValid} />
        </Form>)}
      </Formik>
    </div>
  );
}
