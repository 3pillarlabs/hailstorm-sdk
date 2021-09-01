import React, { useState } from 'react';
import { AmazonCluster, Project } from '../domain';
import { CreateClusterAction } from './actions';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { ApiFactory } from '../api';
import { ClusterViewHeader } from './ClusterViewHeader';
import { useNotifications } from '../app-notifications';
import { AWSForm } from '../AWSForm';
import { FormikActionsHandler } from '../JMeterConfiguration/domain';

export function NewAWSCluster({ dispatch, activeProject }: {
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

  const handleSubmit: FormikActionsHandler = (values, actions) => {
    actions.setSubmitting(true);
    ApiFactory()
      .clusters()
      .create(activeProject.id, {
        ...values as AmazonCluster,
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

  return (
    <div className="card">
      <ClusterViewHeader
        title="Create a new AWS Cluster"
        icon={(<i className="fab fa-aws"></i>)}
      />
      <AWSForm {...{
        awsRegion,
        dispatch,
        handleSubmit,
        setSelectedInstanceType,
        fetchRegions,
        onAWSRegionChange
      }}/>
    </div>
  );
}
