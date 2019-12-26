import { AmazonCluster, DataCenterCluster, Cluster } from "./domain";
import { DB } from "./db";
import { AWSRegionType, AWSRegionList } from "./ClusterConfiguration/domain";
import { ProjectService } from "./services/ProjectService";
import { ExecutionCycleService } from "./services/ExecutionCycleService";
import { ReportService } from "./services/ReportService";
import { JtlExportService } from "./services/JtlExportService";
import { JMeterService } from "./services/JMeterService";
import { JMeterValidationService } from "./services/JMeterValidationService";
import { AWSEC2PricingService } from "./services/AWSEC2PricingService";

export type ResultActions = 'report' | 'export' | 'trash';

export const SLOW_FACTOR = 1;

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

export class AWSRegionService {
  list(): Promise<AWSRegionList> {
    console.log(`api ---- AWSRegionService#list()`);
    return new Promise<AWSRegionList>((resolve, reject) => {
      setTimeout(() => {
        const data: AWSRegionList = {
          regions: [
            {
              code: 'North America',
              title: 'North America',
              regions: [
                { code: 'us-east-1', title: 'US East (Northern Virginia)' },
                { code: 'us-east-2', title: 'US East (Ohio)' },
                { code: 'us-west-1', title: 'US West (Oregon)' },
                { code: 'us-west-2', title: 'US West (Northern California)' },
                { code: 'ca-central-1', title: 'Canada (Central)' }
              ]
            },
            {
              code: 'Europe/Middle East/Africa',
              title: 'Europe/Middle East/Africa',
              regions : [
                { code: 'eu-east-1', title: 'Europe (Ireland)' },
                { code: 'eu-east-2', title: 'Europe (London)' },
                { code: 'eu-central-2', title: 'Europe (Stockholm)' },
                { code: 'eu-central-1', title: 'Europe (Frankfurt)' },
                { code: 'eu-central-3', title: 'Europe (Paris)' },
                { code: 'me-north-1', title: 'Middle East (Bahrain)' },
              ]
            },
            {
              code: 'Asia Pacific',
              title: 'Asia Pacific',
              regions: [
                { code: 'ap-east-1', title: 'Singapore' },
                { code: 'ap-east-2', title: 'Beijing' },
                { code: 'ap-east-3', title: 'Sydney' },
                { code: 'ap-east-4', title: 'Tokyo' },
                { code: 'ap-east-5', title: 'Seoul' },
                { code: 'ap-east-6', title: 'Mainland China (Ningxia)' },
                { code: 'ap-east-7', title: 'Osaka' },
                { code: 'ap-east-8', title: 'Mumbai' },
                { code: 'ap-east-9', title: 'Hong Kong' },

              ]
            },
            {
              code: 'South America',
              title: 'South America',
              regions: [
                { code: 'sa-sa-1', title: 'South America (São Paulo)' }
              ]
            },
          ],

          defaultRegion: { code: 'us-east-1', title: 'US East (Northern Virginia)' }
        };
        resolve(data);
      }, 500 * SLOW_FACTOR);
    });
  }
}

export class ClusterService {
  create(projectId: number, attrs: AmazonCluster | DataCenterCluster): Promise<Cluster> {
    console.log(`api ---- ClusterService#create(${projectId}, ${attrs})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject = DB.projects.find((value) => value.id === projectId);
        if (matchedProject) {
          const createdCluster = {...attrs, id: DB.sys.clusterIndex.nextId()};
          if (createdCluster.type === 'AWS') {
            createdCluster.title = `AWS ${(createdCluster as AmazonCluster).region}`
          }

          createdCluster.code = `cluster-${createdCluster.id}`;
          if (matchedProject.clusters === undefined) {
            matchedProject.clusters = [];
          }

          matchedProject.clusters = [...matchedProject.clusters, createdCluster];
          resolve(createdCluster);
        } else {
          reject(`Project with ID ${projectId} not found`);
        }
      }, 300 * SLOW_FACTOR);
    });
  }

  list(projectId: number): Promise<Cluster[]> {
    console.log(`api ---- ClusterService#list(${projectId})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject = DB.projects.find((value) => value.id === projectId);
        if (matchedProject) {
          if (!matchedProject.incomplete) {
            const awsCluster: AmazonCluster = {
              id: 223, accessKey: 'A', secretKey: 'S', code: 'aws-223', instanceType: 't2.small', maxThreadsByInstance: 25,
              region: 'us-east-1', title: 'AWS us-east-1', type: 'AWS'
            }

            resolve(matchedProject.clusters || [awsCluster]);
          } else {
            resolve(matchedProject.clusters || []);
          }
        } else {
          reject(`No project with id: ${projectId}`);
        }
      }, 300 * SLOW_FACTOR);
    });
  }

  destroy(projectId: number, id: number): Promise<void> {
    console.log(`api ---- ClusterService#destroy(${projectId}, ${id})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject = DB.projects.find((value) => value.id === projectId);
        if (matchedProject) {
          const matchedCluster = matchedProject.clusters!.find((value) => value.id === id);
          if (matchedCluster) {
            matchedProject.clusters = matchedProject.clusters!.filter((value) => value.id !== matchedCluster.id);
            resolve();
          } else {
            reject(`Could not find cluster with ID ${id}, in project with ID ${projectId}`)
          }

        } else {
          reject(`Could not find project with ID: ${projectId}`);
        }
      }, 100 * SLOW_FACTOR);
    });
  }
}

const singletonContext: {[K: string]: any} = {
  apiService: new ApiService()
}

export function ApiFactory() {
  return singletonContext['apiService'] as ApiService;
}
