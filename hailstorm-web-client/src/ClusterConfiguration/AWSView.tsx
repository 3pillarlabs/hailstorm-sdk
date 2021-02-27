import React, { useEffect, useState } from 'react';
import { Project, AmazonCluster } from '../domain';
import { RemoveCluster } from './RemoveCluster';
import styles from './ClusterConfiguration.module.scss';
import { ReadOnlyField } from './ReadOnlyField';
import { ClusterViewHeader } from './ClusterViewHeader';
import { MaxUsersByInstance } from './AWSInstanceChoice';
import { ApiFactory } from '../api';
import { UpdateClusterAction } from './actions';
import { Form, Formik } from 'formik';
import { FormikActionsHandler } from '../JMeterConfiguration/domain';
import { useNotifications } from '../app-notifications';

export function AWSView({ cluster, dispatch, activeProject }: {
  cluster: AmazonCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {
  const {notifySuccess, notifyError} = useNotifications();

  const handleSubmit: FormikActionsHandler = async (values, {resetForm, setSubmitting}) => {
    setSubmitting(true);
    try {
      const updatedCluster = await ApiFactory().clusters().update(
        activeProject!.id,
        cluster.id!,
        { maxThreadsByInstance: values.maxThreadsByInstance }
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

  return (
    <div className="card">
      <ClusterViewHeader
        title={cluster.title}
        icon={(<i className="fab fa-aws"></i>)}
      />
      <Formik initialValues={{maxThreadsByInstance: cluster.maxThreadsByInstance}} onSubmit={handleSubmit}>
        {props => (
          <Form>
            <div className={`card-content${cluster.disabled ? ` ${styles.disabledContent}` : ''}`}>
              <div className="content">
                <ReadOnlyField label="AWS Access Key" value={cluster.accessKey} />
                <ReadOnlyField label="VPC Subnet" value={cluster.vpcSubnetId} />
                <ReadOnlyField label="AWS Region" value={cluster.region} />
                <ReadOnlyField label="AWS Instance Type" value={cluster.instanceType} />
                {cluster.disabled || !dispatch ? (
                  <ReadOnlyField label="Max. Users / Instance" value={cluster.maxThreadsByInstance} />
                ) : (
                  <MaxUsersByInstance
                    onChange={(event) => {
                      if (event.target.value && parseInt(event.target.value) > 0) {
                        props.handleChange(event);
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
                    disabled={props.isSubmitting || !props.dirty}
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
