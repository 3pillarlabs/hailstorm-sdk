import React, { useState, useEffect } from 'react';
import { ToolBar } from './ToolBar';
import { ExecutionCycleGrid } from './ExecutionCycleGrid';
import { ExecutionCycle, Project } from '../domain';

export interface CheckedExecutionCycle extends ExecutionCycle {
  checked: boolean | null;
}

export interface ButtonStateLookup {
  report: boolean;
  export: boolean;
  trash: boolean;
  stop: boolean;
  abort: boolean;
  start: boolean;
}

export interface ControlPanelProps {
  reloadReports: () => void;
  setWaitingForReport: React.Dispatch<React.SetStateAction<boolean>>;
  dispatch: React.Dispatch<any>;
  project: Project;
}

export const ControlPanel: React.FC<ControlPanelProps> = ({
  reloadReports,
  setWaitingForReport,
  project,
  dispatch
}) => {
  const [gridButtonStates, setGridButtonStates] = useState<ButtonStateLookup>({
    report: true,
    export: true,
    trash: false,
    stop: true,
    abort: true,
    start: false,
  });

  const [executionCycles, setExecutionCycles] = useState<CheckedExecutionCycle[]>([]);
  const [reloadGrid, setReloadGrid] = useState(false);
  const [viewTrash, setViewTrash] = useState(false);

  useEffect(() => setGridButtonStates({
    ...gridButtonStates,
    stop: !project.running || project.autoStop || project.interimState !== undefined,
    abort: !project.running || project.interimState !== undefined,
    start: project.running || project.interimState !== undefined,
  }), [project]);

  return (
    <>
    <div className="panel">
      <div className="panel-heading">
        <i className="fas fa-flask"></i> Tests
      </div>
      <ToolBar {...{
        executionCycles,
        setExecutionCycles,
        gridButtonStates,
        setGridButtonStates,
        viewTrash,
        setReloadGrid,
        reloadReports,
        setViewTrash,
        project,
        dispatch,
        setWaitingForReport
      }}>
        <div className="panel-block">
          <ExecutionCycleGrid {...{
            gridButtonStates,
            setGridButtonStates,
            viewTrash,
            reloadGrid,
            setReloadGrid,
            executionCycles,
            setExecutionCycles,
            project
          }}/>
        </div>
      </ToolBar>
    </div>
    </>
  );
}
