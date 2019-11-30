// domain types

export interface Project {
  id: number;
  code: string;
  title: string;
  running: boolean;
  currenExecutionCycle?: ExecutionCycle;
  lastExecutionCycle?: ExecutionCycle;
  autoStop?: boolean;
  interimState?: InterimProjectState;
  jmeter?: JMeter;
  clusters?: Cluster[];
  incomplete?: boolean;
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
  ABORTING = "aborting",
  TERMINATING = "terminating",
  DELETING = "deleting",
}

export interface LogEvent {
  projectCode?: string;
  timestamp: number;
  priority: number;
  level: string;
  message: string;
}

export interface JMeter {
  version?: string;
  files: JMeterFile[];
}

export interface JMeterFile {
  id?: number;
  name: string;
  properties?: Map<string, string | undefined>;
  dataFile?: boolean;
  disabled?: boolean;
  path?: string;
}

export interface ValidationNotice {
  type: 'warning' | 'error';
  message: string;
}

export interface Cluster {
  title: string;
  type: 'AWS' | 'DataCenter';
  id?: number;
  code?: string;
  disabled?: boolean;
}

export interface AmazonCluster extends Cluster {
  accessKey: string;
  secretKey: string;
  region: string;
  instanceType: string;
  vpcSubnetId?: string;
  maxThreadsByInstance: number;
}

export interface DataCenterCluster extends Cluster {
  userName: string;
  sshIdentity: {name: string, path?: string};
  machines: string[];
  sshPort?: number;
}
