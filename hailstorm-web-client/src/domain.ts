// domain types

export interface Project {
  id: number;
  code: string;
  title: string;
  running: boolean;
  currenExecutionCycle?: ExecutionCycle;
  recentExecutionCycle?: ExecutionCycle;
  autoStop: boolean;
  interimState?: InterimProjectState;
}

export interface ExecutionCycle {
  id: number;
  projectId: number;
  startedAt: Date;
  stoppedAt?: Date | undefined;
  status?: ExecutionCycleStatus;
  threadsCount?: number;
  responseTime?: number;
  throughput?: number;
}

export enum ExecutionCycleStatus {
  STOPPED = "stopped",
  ABORTED = "aborted",
  FAILED = "failed",
  EXCLUDED = "excluded",
}

export interface Report {
  id: number;
  projectId: number;
  title: string;
}

export interface JtlFile {
  title: string;
  url: string;
}

export enum InterimProjectState {
  STARTING = "starting",
  STOPPING = "stopping",
  ABORTING = "aborting"
}
