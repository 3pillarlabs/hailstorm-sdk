// domain types

export interface Project {
  id: number;
  code: string;
  title: string;
  running: boolean;
  currenExecutionCycle?: ExecutionCycle;
  recentExecutionCycle?: ExecutionCycle;
}

export interface ExecutionCycle {
  startedAt: Date;
  stoppedAt: Date | undefined;
  status: ExecutionCycleStatus;
}

export enum ExecutionCycleStatus {
  STOPPED,
  ABORTED,
  FAILED
}
