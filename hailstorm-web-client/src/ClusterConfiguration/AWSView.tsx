import React, { useState } from 'react';
import { Project, AmazonCluster } from '../domain';
import { RemoveCluster } from './RemoveCluster';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';
import { ReadOnlyField } from './ReadOnlyField';
import { ClusterViewHeader } from './ClusterViewHeader';
import { MaxUsersByInstance } from './AWSInstanceChoice';
import { ApiFactory } from '../api';
import { UpdateClusterAction } from './actions';
import { Form, Formik } from 'formik';
import { FormikActionsHandler } from '../JMeterConfiguration/domain';
import { useNotifications } from '../app-notifications';
import { AWSFormField, AWSInstanceChoiceField } from './AWSFormField';
import _ from 'lodash';
import { AWSInstanceChoiceOption } from './domain';

export function AWSView({ cluster, dispatch, activeProject }: {
  cluster: AmazonCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {
  const {notifySuccess, notifyError} = useNotifications();
  const [selectedInstanceType, setSelectedInstanceType] = useState<AWSInstanceChoiceOption>();

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

  const handleSubmit: FormikActionsHandler = async (values, {resetForm, setSubmitting}) => {
    setSubmitting(true);
    const valuesToUpdate: {[K in keyof AmazonCluster]?: AmazonCluster[K]} = {};
    ["accessKey", "secretKey", "instanceType", "maxThreadsByInstance", "vpcSubnetId", "baseAMI"].forEach((attribute) => {
      if (_.get(cluster, attribute) !== values[attribute]) {
        _.set(valuesToUpdate, attribute, values[attribute]);
      }
    });

    if (selectedInstanceType) {
      _.assign(valuesToUpdate, {..._.pick(selectedInstanceType, "instanceType", "maxThreadsByInstance")});
    }

    try {
      const updatedCluster = await ApiFactory().clusters().update(
        activeProject!.id,
        cluster.id!,
        valuesToUpdate
      );

      dispatch && dispatch(new UpdateClusterAction(updatedCluster));
      resetForm(values);
      notifySuccess(`Saved ${updatedCluster.title} cluster configuration`);
    } catch (error) {
      notifyError("Failed to update cluster configuration", error);
    } finally {
      setSubmitting(false);
    }
  };

  const staticField = cluster.disabled || (!!activeProject && activeProject.live) || !dispatch;

  return (
    <div className="card">
      <ClusterViewHeader
        title={cluster.title}
        icon={(<i className="fab fa-aws"></i>)}
      />
      <Formik
        initialValues={{...cluster}}
        onSubmit={handleSubmit}
        validate={validateInputs}
        isInitialValid={true}
      >
        {props => (
          <Form>
            <div className={`card-content${staticField ? ` ${styles.disabledContent}` : ''}`}>
              <div className="content">
                <AWSFormField labelText="AWS Access Key" fieldName="accessKey" fieldValue={cluster.accessKey} {...{staticField}} required={true} />
                {!staticField && (
                <AWSFormField labelText="AWS Secret Key" fieldName="secretKey" fieldValue={cluster.secretKey} {...{staticField}} required={true} />)}
                <AWSFormField labelText="VPC Subnet" fieldName="vpcSubnetId" fieldValue={cluster.vpcSubnetId} {...{staticField}} />
                <ReadOnlyField label="AWS Region" value={cluster.region} />
                {cluster.baseAMI && (<AWSFormField labelText="Base AMI" fieldName="baseAMI" fieldValue={cluster.baseAMI} {...{staticField}} required={true} />)}
                {staticField ? (<>
                <ReadOnlyField label="AWS Instance Type" value={cluster.instanceType} />
                </>) : (
                  <AWSInstanceChoiceField
                    awsRegion={cluster.region}
                    maxThreadsByInstance={cluster.maxThreadsByInstance}
                    instanceType={cluster.instanceType}
                    {...{setSelectedInstanceType}}
                    disabled={props.isSubmitting}
                    onChange={() => props.setFieldTouched("instanceType")}
                  />
                )}
                {cluster.disabled && (
                <ReadOnlyField label="Max. Users / Instance" value={cluster.maxThreadsByInstance} />
                )}
                {!cluster.disabled && activeProject && activeProject.live && (
                <MaxUsersByInstance
                  onChange={(event) => {
                    if (event.target.value && parseInt(event.target.value) > 0) {
                      props.handleChange(event);
                      props.setFieldTouched("maxThreadsByInstance");
                    }
                  }}
                  value={props.values.maxThreadsByInstance}
                />
                )}
              </div>
            </div>
            {activeProject && dispatch && (
            <div className="card-footer">
              <RemoveCluster {...{activeProject, cluster, dispatch}} />
              {!cluster.disabled && (
                <div className="card-footer-item">
                  <button
                    type="submit"
                    className="button is-primary"
                    role="Update Cluster"
                    disabled={props.isSubmitting || !props.isValid}
                  >
                    Update
                  </button>
                </div>
              )}
            </div>)}
          </Form>
        )}
      </Formik>
    </div>
  );
}
