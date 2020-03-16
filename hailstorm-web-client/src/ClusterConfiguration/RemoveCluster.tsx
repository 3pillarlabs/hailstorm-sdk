import React, { useState } from "react";
import { DataCenterCluster, AmazonCluster, Project, Cluster } from "../domain";
import { ApiFactory } from "../api";
import { RemoveClusterAction, ActivateClusterAction } from "./actions";

export function RemoveCluster({
  cluster,
  dispatch,
  activeProject
}: {
  cluster: AmazonCluster | DataCenterCluster;
  dispatch: React.Dispatch<any>;
  activeProject: Project;
}) {
  const [disableRemove, setDisableRemove] = useState(false);
  const removeHandler = () => {
    if (cluster.id) {
      setDisableRemove(true);
      ApiFactory()
      .clusters()
      .destroy(activeProject.id, cluster.id!)
      .then(() => {
        delete cluster.disabled;
        dispatch(new RemoveClusterAction(cluster));
      })
      .finally(() => setDisableRemove(false));

    } else {
      dispatch(new RemoveClusterAction(cluster));
    }
  };

  const disableHandler = () => {
    if (cluster.id) {
      setDisableRemove(true);
      ApiFactory()
      .clusters()
      .update(activeProject.id, cluster.id!, {disabled: true})
      .then(() => {
        const payload: Cluster = {...cluster, disabled: true};
        dispatch(new RemoveClusterAction(payload));
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
      .update(activeProject.id, cluster.id!, {disabled: false})
      .then((updated) => {
        dispatch(new ActivateClusterAction({...updated, disabled: false}));
        setDisableRemove(false);
      });
  };

  let showRemoveButton: boolean;
  if (cluster.clientStatsCount || cluster.loadAgentsCount) {
    showRemoveButton = false;
  } else {
    showRemoveButton = true;
  }

  return (
    <>
    {showRemoveButton && (
      <div className="card-footer-item">
        <RemoveButton {...{disableRemove, removeHandler}} buttonLabel="Remove" />
      </div>
    )}
    {cluster.disabled ?
    (
      <div className="card-footer-item">
        <EnableButton {...{disableRemove, enableHandler}} />
      </div>
    ) :
    (
      <div className="card-footer-item">
        <RemoveButton {...{disableRemove}} buttonLabel="Disable" removeHandler={disableHandler} />
      </div>
    )}
    </>
  );
}

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
    <button
      type="button"
      className="button is-warning"
      role={`${buttonLabel} Cluster`}
      disabled={disableRemove}
      onClick={removeHandler}
    >
      {buttonLabel}
    </button>
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
    <button
      type="button"
      className="button is-warning"
      role="Enable Cluster"
      disabled={disableRemove}
      onClick={enableHandler}
    >
      Enable
    </button>
  );
}
