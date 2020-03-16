import { ProjectService } from "./services/ProjectService";
import { ExecutionCycleService } from "./services/ExecutionCycleService";
import { ReportService } from "./services/ReportService";
import { JtlExportService } from "./services/JtlExportService";
import { JMeterService } from "./services/JMeterService";
import { JMeterValidationService } from "./services/JMeterValidationService";
import { AWSEC2PricingService } from "./services/AWSEC2PricingService";
import { AWSRegionService } from "./services/AWSRegionService";
import { ClusterService } from "./services/ClusterService";

export type ResultActions = 'report' | 'export' | 'trash';

// API
export class ApiService {

  singletonContext: {[K: string]: any} = {
    projects: new ProjectService(),
    executionCycles: new ExecutionCycleService(),
    reports: new ReportService(),
    jtlExports: new JtlExportService(),
    jmeter: new JMeterService(),
    jmeterValidation: new JMeterValidationService(),
    awsInstancePricing: new AWSEC2PricingService(),
    awsRegion: new AWSRegionService(),
    clusters: new ClusterService(),
  };

  projects() {
    return this.singletonContext['projects'] as ProjectService;
  }

  executionCycles() {
    return this.singletonContext['executionCycles'] as ExecutionCycleService;
  }

  reports() {
    return this.singletonContext['reports'] as ReportService;
  }

  jtlExports() {
    return this.singletonContext['jtlExports'] as JtlExportService;
  }

  jmeter() {
    return this.singletonContext['jmeter'] as JMeterService;
  }

  jmeterValidation() {
    return this.singletonContext['jmeterValidation'] as JMeterValidationService;
  }

  awsInstancePricing() {
    return this.singletonContext['awsInstancePricing'] as AWSEC2PricingService;
  }

  awsRegion() {
    return this.singletonContext['awsRegion'] as AWSRegionService;
  }

  clusters() {
    return this.singletonContext['clusters'] as ClusterService;
  }
}

const singletonContext: {[K: string]: any} = {
  apiService: new ApiService()
}

export function ApiFactory() {
  return singletonContext['apiService'] as ApiService;
}
