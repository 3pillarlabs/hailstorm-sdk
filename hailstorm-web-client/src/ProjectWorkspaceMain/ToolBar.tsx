import React, { useState, useContext, useEffect } from 'react';
import { ButtonStateLookup, CheckedExecutionCycle } from './ControlPanel';
import { ResultActions, ApiFactory } from '../api';
import { ProjectActions } from '../services/ProjectService';
import { JtlDownloadContentProps, JtlDownloadModal } from './JtlDownloadModal';
import { Modal } from '../Modal';
import { InterimProjectState } from '../domain';
import { SetInterimStateAction, UnsetInterimStateAction, SetRunningAction, UpdateProjectAction } from '../ProjectWorkspace/actions';
import { AppStateContext } from '../appStateContext';
import { interval, Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';

export interface ToolBarProps {
  gridButtonStates: ButtonStateLookup;
  setGridButtonStates: React.Dispatch<React.SetStateAction<ButtonStateLookup>>;
  viewTrash: boolean;
  setViewTrash: React.Dispatch<React.SetStateAction<boolean>>;
  executionCycles: CheckedExecutionCycle[];
  setExecutionCycles: React.Dispatch<React.SetStateAction<CheckedExecutionCycle[]>>;
  setReloadGrid: React.Dispatch<React.SetStateAction<boolean>>;
  reloadReports: () => void;
  statusCheckInterval?: number;
}

export const ToolBar: React.FC<ToolBarProps> = (props) => {
  const {
    gridButtonStates,
    setGridButtonStates,
    viewTrash,
    setViewTrash,
    executionCycles,
    setExecutionCycles,
    setReloadGrid,
    reloadReports,
    statusCheckInterval
  } = props;

  const {appState, dispatch} = useContext(AppStateContext);
  const project = appState.activeProject!;
  const [showJtlModal, setShowJtlModal] = useState(false);
  const [jtlModalProps, setJtlModalProps] = useState<JtlDownloadContentProps>({});

  const toggleTrash = () => {
    const nextState = !viewTrash;
    setViewTrash(nextState);
    setGridButtonStates({
      ...gridButtonStates,
      stop: nextState ? true : (!project.running || project.autoStop || false),
      abort: nextState ? true : !project.running,
      start: nextState ? true : project.running
    });

    if (nextState) {
      setExecutionCycles(executionCycles.map((exCycle) => ({...exCycle, checked: false})));
    }
  };

  const toggleRunning = (endState: boolean, action?: ProjectActions) => {
    return () => {
      setGridButtonStates({ ...gridButtonStates, stop: true, abort: true, start: true });
      switch (action) {
        case "start":
          dispatch(new SetInterimStateAction(InterimProjectState.STARTING));
          break;

        case "stop":
          dispatch(new SetInterimStateAction(InterimProjectState.STOPPING));
          break;

        case "abort":
          dispatch(new SetInterimStateAction(InterimProjectState.ABORTING));
          break;

        default:
          break;
      }

      ApiFactory()
        .projects()
        .update(project.id, { running: endState, action })
        .then(() => ApiFactory().projects().get(project.id))
        .then((project) => dispatch(new UpdateProjectAction(project)))
        .then(() => dispatch(new UnsetInterimStateAction()))
        .then(() => dispatch(new SetRunningAction(endState)))
        .then(() => setReloadGrid(true))
        .catch((reason) => {
          console.error(reason);
          dispatch(new UnsetInterimStateAction());
        });
    };
  }

  const resultsHandler = (action: ResultActions) => {
    return () => {
      setGridButtonStates({ ...gridButtonStates, [action]: true });
      const executionCycleIds = executionCycles.filter((exCycle) => exCycle.checked).map((exCycle) => exCycle.id);
      switch (action) {
        case "report":
          ApiFactory()
            .reports()
            .create(project.id, executionCycleIds)
            .then(reloadReports)
            .then(() =>
              setGridButtonStates({ ...gridButtonStates, [action]: false })
            );

          break;

        case "export":
          ApiFactory()
            .jtlExports()
            .create(project.id, executionCycleIds)
            .then(({title, url}) => {
              setJtlModalProps({title, url});
              setShowJtlModal(true);
            })
            .then(() =>
              setGridButtonStates({ ...gridButtonStates, [action]: false })
            );

          break;

        default:
          break;
      }
    };
  };

  useEffect(() => {
    console.debug('ToolBar#useEffect(project)');
    let cb: (() => void) | undefined = undefined;
    if (project.running && project.autoStop) {
      const period = statusCheckInterval || 3 * 60 * 1000;  // emit every 3 minutes by default
      const tick$ = interval(period);
      const subject = new Subject<void>();
      tick$
        .pipe(
          takeUntil(subject)
        )
        .subscribe(async () => {
          try {
            const exCycleStatus = await ApiFactory().executionCycles().get(project.id);
            if (exCycleStatus.noRunningTests) {
              subject.next();
              subject.complete();
              toggleRunning(false, 'stop')();
            }
          } catch (error) {
            console.error(`Error getting status of current tests: ${error.message}`);
            subject.next();
            subject.complete();
          }
      });

      cb = () => {
        subject.next();
        subject.complete();
      };
    }

    return cb;

  }, [project]);

  return (
    <>
    <div className="panel-block">
      <div className="level">
        <div className="level-left">
          <div className="level-item">
            <button
              name="stop"
              className="button is-small is-light"
              onClick={toggleRunning(false, "stop")}
              disabled={gridButtonStates.stop}
            >
              <i className="fas fa-stop-circle"></i> Stop
            </button>
          </div>
          <div className="level-item">
            <button
              name="abort"
              className="button is-small is-danger"
              onClick={toggleRunning(false, "abort")}
              disabled={gridButtonStates.abort}
            >
              <i className="fa fa-ban"></i> Abort
            </button>
          </div>
        </div>
        <div className="level-right">
          <div className="level-item">
            <button name="report" className="button is-small" onClick={resultsHandler("report")} disabled={gridButtonStates.report}>
              <i className="fas fa-chart-line"></i> Report
            </button>
          </div>
          <div className="level-item">
            <button name="export" className="button is-small" onClick={resultsHandler("export")} disabled={gridButtonStates.export}>
              <i className="fas fa-download"></i> Export
            </button>
          </div>
          <div className="level-item">
            <button
              name="start"
              className="button is-small is-primary"
              disabled={gridButtonStates.start}
              onClick={toggleRunning(true, "start")}
            >
              <i className="fas fa-play-circle"></i> Start
            </button>
          </div>
        </div>
      </div>
    </div>
    {props.children}
    <div className="panel-block is-gtk">
      <div className="level">
        <div className="level-left">
        </div>
        <div className="level-right">
          <div className="level-item">
            <button name="trash" className="button is-small" disabled={gridButtonStates.trash} onClick={toggleTrash}>
            {viewTrash ?
              <span><i className="fas fa-trash-restore"></i> Close Trash</span> :
              <span><i className="fas fa-trash"></i> Open Trash</span>}
            </button>
          </div>
        </div>
      </div>
    </div>
    <Modal isActive={showJtlModal}>
      <JtlDownloadModal isActive={showJtlModal} setActive={setShowJtlModal} title={jtlModalProps.title} url={jtlModalProps.url} />
    </Modal>
    </>
  );
}
