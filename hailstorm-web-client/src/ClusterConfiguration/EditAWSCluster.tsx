import React, { useState } from 'react';
import { Project, AmazonCluster } from '../domain';
import { ClusterViewHeader } from './ClusterViewHeader';
import { ApiFactory } from '../api';
import { UpdateClusterAction } from './actions';
import { FormikActionsHandler } from '../JMeterConfiguration/domain';
import { useNotifications } from '../app-notifications';
import _ from 'lodash';
import { AWSInstanceChoiceOption } from './domain';
import { AWSForm } from './AWSForm';

export function EditAWSCluster({ cluster, dispatch, activeProject }: {
  cluster: AmazonCluster;
  dispatch?: React.Dispatch<any>;
  activeProject?: Project;
}) {
  const {notifySuccess, notifyError} = useNotifications();
  const [selectedInstanceType, setSelectedInstanceType] = useState<AWSInstanceChoiceOption>();
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
  const formMode = staticField ? 'readonly' : 'edit'

  return (
    <div className="card">
      <ClusterViewHeader
        title={cluster.title}
        icon={(<i className="fab fa-aws"></i>)}
      />
      <AWSForm
        awsRegion={cluster.region}
        {...{
          dispatch,
          activeProject,
          cluster,
          handleSubmit,
          setSelectedInstanceType,
          formMode
      }}/>
    </div>
  );
}
