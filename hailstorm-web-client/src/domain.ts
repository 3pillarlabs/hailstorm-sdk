// domain types

export interface Project {
  id: number;
  code: string;
  title: string;
  running: boolean;
  currentExecutionCycle?: ExecutionCycle;
  lastExecutionCycle?: ExecutionCycle;
  autoStop?: boolean;
  interimState?: InterimProjectState;
  jmeter?: JMeter;
  clusters?: Cluster[];
  incomplete?: boolean;
  destroyed?: boolean;
  live?: boolean;
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
  uri: string;
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
  DELETING = "deleting"
}

export interface LogEvent {
  id?: number;
  projectCode?: string;
  timestamp: number;
  priority: number;
  level: 'debug' | 'info' | 'warn' | 'error' | 'fatal';
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
  planExecutedBefore?: boolean;
}

export interface ValidationNotice {
  type: 'warning' | 'error';
  message: string;
}

export interface ClusterCommonInput {
  title: string;
}

export interface Cluster extends ClusterCommonInput {
  type: 'AWS' | 'DataCenter';
  id?: number;
  code?: string;
  disabled?: boolean;
  clientStatsCount?: number;
  loadAgentsCount?: number;
}

export interface AmazonCluster extends Cluster {
  accessKey: string;
  secretKey: string;
  region: string;
  instanceType: string;
  vpcSubnetId?: string;
  maxThreadsByInstance: number;
  baseAMI?: string;
}

export interface DataCenterClusterInputs extends ClusterCommonInput {
  userName: string;
  sshPort?: number;
  machines: string[];
}
export interface DataCenterCluster extends DataCenterClusterInputs, Cluster {
  sshIdentity: {name: string, path?: string};
}
