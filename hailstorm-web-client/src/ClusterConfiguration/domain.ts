export interface AWSRegionType {
  code: string;
  title: string;
  regions?: AWSRegionType[];
}

export interface AWSRegionList {
  defaultRegion: AWSRegionType;
  regions: AWSRegionType[];
}

interface AWSInstanceChoiceOptionType {
  instanceType: string;
  maxThreadsByInstance: number;
  hourlyCostByInstance?: number;
  numInstances?: number;
}

export class AWSInstanceChoiceOption implements AWSInstanceChoiceOptionType {
  public instanceType: string;
  public maxThreadsByInstance: number;
  public hourlyCostByInstance: number;
  public numInstances: number;

  static DEFAULT_MAX_INSTANCES_PER_CLUSTER: number = 20;

  constructor(attrs: AWSInstanceChoiceOptionType) {
    this.instanceType = attrs.instanceType;
    this.maxThreadsByInstance = attrs.maxThreadsByInstance;
    this.hourlyCostByInstance = attrs.hourlyCostByInstance || 0;
    this.numInstances = attrs.numInstances || 0;
  }

  hourlyCostByCluster() {
    return this.hourlyCostByInstance * this.numInstances;
  }
}
