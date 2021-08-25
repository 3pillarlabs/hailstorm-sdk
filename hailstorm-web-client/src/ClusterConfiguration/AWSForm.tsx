import React from 'react';
import { Form, Formik } from 'formik';
import { AmazonCluster, Project } from '../domain';
import { FormikActionsHandler } from '../JMeterConfiguration/domain';
import { AWSFormField, AWSInstanceChoiceField } from './AWSFormField';
import { AWSRegionChoice } from './AWSRegionChoice';
import { ClusterFormFooter } from './ClusterFormFooter';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { ReadOnlyField } from './ReadOnlyField';
import { MaxUsersByInstance } from './AWSInstanceChoice';
import { RemoveCluster } from './RemoveCluster';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';

export function AWSForm({
  cluster,
  handleSubmit,
  awsRegion,
  dispatch,
  fetchRegions,
  onAWSRegionChange,
  setSelectedInstanceType,
  formMode = 'new',
  activeProject
}: {
  dispatch?: React.Dispatch<any>;
  handleSubmit: FormikActionsHandler;
  awsRegion: string | undefined;
  setSelectedInstanceType: React.Dispatch<React.SetStateAction<AWSInstanceChoiceOption | undefined>>
  cluster?: AmazonCluster;
  fetchRegions?: () => Promise<AWSRegionList>;
  onAWSRegionChange?: (region: string, options?: { baseAMI?: string }) => void;
  formMode?: 'new' | 'edit' | 'readonly';
  activeProject?: Project;
}) {

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

  const initialValues = {accessKey: '', secretKey: '', maxThreadsByInstance: 0, ...cluster};
  const readOnlyMode = formMode === 'readonly';

  return (
    <Formik
      isInitialValid={formMode !== 'new'}
      initialValues={initialValues}
      validate={validateInputs}
      onSubmit={(values, actions) => handleSubmit(values, actions)}
    >
      {({ isSubmitting, isValid, setFieldTouched, handleChange, values }) => (
      <Form data-testid="AWSForm">
        <div className={`card-content${cluster && cluster.disabled ? ` ${styles.disabledContent}` : ''}`}>
          <AWSFormField
            labelText="AWS Access Key"
            required={true}
            disabled={isSubmitting}
            fieldName="accessKey"
            fieldValue={cluster && cluster.accessKey}
            staticField={readOnlyMode}
          />
          {!readOnlyMode && (
          <AWSFormField
            labelText="AWS Secret Key"
            fieldName="secretKey"
            staticField={readOnlyMode}
            inputType={'password'}
            disabled={isSubmitting}
            required={true}
          />)}
          <AWSFormField
            labelText="VPC Subnet"
            fieldName="vpcSubnetId"
            fieldValue={cluster && cluster.vpcSubnetId}
            staticField={readOnlyMode}
            disabled={isSubmitting}
          />
          {formMode === 'new' ? (
          <div className="field">
            <label className="label">AWS Region *</label>
            <div className="control">
              <AWSRegionChoice fetchRegions={fetchRegions!} onAWSRegionChange={onAWSRegionChange!} disabled={isSubmitting} />
            </div>
          </div>) : (
          <>
          <ReadOnlyField
            label="AWS Region"
            value={cluster && cluster.region}
          />
          {cluster && cluster.baseAMI && (
          <AWSFormField
            labelText="Base AMI"
            fieldName="baseAMI"
            fieldValue={cluster.baseAMI}
            staticField={readOnlyMode}
            required={true}
          />)}
          </>)}
          {readOnlyMode ? (
          <ReadOnlyField label="AWS Instance Type" value={cluster!.instanceType} />
          ) : (
          <AWSInstanceChoiceField
            awsRegion={awsRegion || (cluster && cluster.region!) || ''}
            {...{setSelectedInstanceType}}
            disabled={isSubmitting}
            maxThreadsByInstance={cluster && cluster.maxThreadsByInstance}
            instanceType={cluster && cluster.instanceType}
            onChange={() => setFieldTouched("instanceType")}
          />)}
          {cluster && (cluster.disabled || (!activeProject && readOnlyMode)) && (
          <ReadOnlyField label="Max. Users / Instance" value={cluster.maxThreadsByInstance} />
          )}
          {cluster && !cluster.disabled && activeProject && activeProject.live && (
          <MaxUsersByInstance
            onChange={(event) => {
              if (event.target.value && parseInt(event.target.value) > 0) {
                handleChange(event);
                setFieldTouched("maxThreadsByInstance");
              }
            }}
            value={values.maxThreadsByInstance}
          />
          )}
        </div>
        {formMode === 'new' && dispatch ? (
        <ClusterFormFooter {...{dispatch}} disabled={isSubmitting || !isValid} />
        ) : (
        activeProject && cluster && dispatch && (
        <div className="card-footer">
          <RemoveCluster {...{activeProject, cluster, dispatch}} />
          {!cluster.disabled && (
            <div className="card-footer-item">
              <button
                type="submit"
                className="button is-primary"
                role="Update Cluster"
                disabled={isSubmitting || !isValid}
              >
                Update
              </button>
            </div>
          )}
        </div>)
        )}
      </Form>)}
    </Formik>
  );
}
