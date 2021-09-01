import React, { useState } from 'react';
import { ApiFactory } from '../api';
import { useNotifications } from '../app-notifications';
import { Cluster, Project } from '../domain';
import { ActivateClusterAction, RemoveClusterAction } from './actions';

function RemoveButton({
  disableRemove,
  removeHandler,
  buttonLabel
}: {
  disableRemove: boolean;
  removeHandler: () => void;
  buttonLabel: string;
}) {
  return (
    <div className="card-footer-item">
      <button
        type="button"
        className="button is-warning"
        role={`${buttonLabel} Cluster`}
        disabled={disableRemove}
        onClick={removeHandler}
      >
        {buttonLabel}
      </button>
    </div>
  );
}

function EnableButton({
  disableRemove,
  enableHandler
}: {
  disableRemove: boolean;
  enableHandler: () => void;
}) {
  return (
    <div className="card-footer-item">
      <button
        type="button"
        className="button is-warning"
        role="Enable Cluster"
        disabled={disableRemove}
        onClick={enableHandler}
      >
        Enable
      </button>
    </div>
  );
}

function EnableOrDisable({
  cluster,
  disableRemove,
  enableHandler,
  disableHandler
}: {
  cluster?: Cluster;
  disableRemove: boolean;
  enableHandler: () => void;
  disableHandler: () => void;
}) {
  return (
    cluster!.disabled ? (
      <EnableButton {...{ disableRemove, enableHandler }} />
    ) : (
      <RemoveButton {...{ disableRemove }} buttonLabel="Disable" removeHandler={disableHandler} />
    )
  );
}

function SaveOrUpdate({
  newCluster,
  disabled
}: {
  newCluster?: boolean,
  disabled: boolean
}) {
  return (
    <div className="card-footer-item">
      {newCluster ? (
        <button type="submit" className="button is-dark" disabled={disabled}>Save</button>
      ) : (
        <button
          type="submit"
          className="button is-primary"
          role="Update Cluster"
          {...{ disabled }}
        >
          Update
        </button>
      )}
    </div>
  );
}

export function ClusterFormFooter({
  dispatch,
  disabled,
  newCluster,
  cluster,
  activeProject
}: {
  dispatch: React.Dispatch<any>;
  disabled: boolean;
  newCluster?: boolean;
  cluster?: Cluster;
  activeProject?: Project;
}) {
  const [disableRemove, setDisableRemove] = useState(false);
  const notifiers = useNotifications();
  const clusterUsed = activeProject && cluster && (cluster.clientStatsCount || cluster.loadAgentsCount);
  const showRemoveButton = newCluster || !clusterUsed;
  const showEnableOrDisable = !newCluster;
  const showPrimaryTrigger = newCluster || (cluster && !cluster.disabled);

  const removeHandler = () => {
    if (cluster && cluster.id) {
      setDisableRemove(true);
      ApiFactory()
      .clusters()
      .destroy(activeProject!.id, cluster.id)
      .then(() => {
        delete cluster.disabled;
        dispatch(new RemoveClusterAction(cluster));
        notifiers.notifySuccess(`Removed cluser ${cluster.title} from configuration`);
      })
      .finally(() => setDisableRemove(false));
    } else if (cluster) {
      dispatch(new RemoveClusterAction(cluster));
    } else {
      dispatch(new RemoveClusterAction());
    }
  };

  const disableHandler = () => {
    if (cluster!.id) {
      setDisableRemove(true);
      ApiFactory()
      .clusters()
      .update(activeProject!.id, cluster!.id!, {disabled: true})
      .then(() => {
        const payload: Cluster = {...cluster!, disabled: true};
        dispatch(new RemoveClusterAction(payload));
        notifiers.notifyWarning(`Disabled cluser ${cluster!.title} configuration`);
      })
      .finally(() => setDisableRemove(false));

    } else {
      dispatch(new RemoveClusterAction(cluster));
    }
  };

  const enableHandler = () => {
    setDisableRemove(true);
    ApiFactory()
      .clusters()
      .update(activeProject!.id, cluster!.id!, {disabled: false})
      .then((updated) => {
        dispatch(new ActivateClusterAction({...updated, disabled: false}));
        setDisableRemove(false);
        notifiers.notifySuccess(`Enabled cluser ${cluster!.title} configuration`);
      });
  };


  return (
    <div className="card-footer">
    {showRemoveButton && (
      <RemoveButton {...{disableRemove, removeHandler}} buttonLabel="Remove" />
    )}
    {showEnableOrDisable && (
      <EnableOrDisable {...{cluster, disableRemove, enableHandler, disableHandler}} />
    )}
    {showPrimaryTrigger && (
      <SaveOrUpdate {...{newCluster, disabled}} />
    )}
    </div>
  )
}

