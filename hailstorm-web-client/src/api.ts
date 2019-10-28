import { Project, ExecutionCycleStatus, ExecutionCycle, Report, JtlFile, JMeter, JMeterFile, AmazonCluster, DataCenterCluster, Cluster } from "./domain";
import { DB } from "./db";
import { JMeterFileUploadState } from "./NewProjectWizard/domain";
import { AWSInstanceChoiceOption, AWSRegionType, AWSRegionList } from "./ClusterConfiguration/domain";

export type ProjectActions = 'stop' | 'abort' | 'start' | 'terminate';
export type ResultActions = 'report' | 'export' | 'trash';

const SLOW_FACTOR = 1;

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

export class ProjectService {

  list(): Promise<Project[]> {
    console.log(`api ---- ProjectService#list()`);
    return new Promise((resolve, reject) => {
      setTimeout(() => resolve(DB.projects.map((x) => {
        const currentExecutionCycle:
          | ExecutionCycle
          | undefined = DB.executionCycles.find(
          exCycle => !exCycle.stoppedAt && exCycle.projectId === x.id
        );
        return {...x, currenExecutionCycle: currentExecutionCycle};
      })), 300 * SLOW_FACTOR);
    });
  }

  get(id: number): Promise<Project> {
    console.log(`api ---- ProjectService#get(${id})`);
    let matchedProject: Project | undefined = DB.projects.find((project) => project.id === id);
    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => resolve({...matchedProject} as Project), 100 * SLOW_FACTOR);
      } else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500 * SLOW_FACTOR);
      }
    });
  }

  update(id: number, attributes: {title?: string, running?: boolean, action?: ProjectActions}): Promise<void> {
    console.log(`api ---- ProjectService#update(${id}, ${Object.keys(attributes)}, ${Object.values(attributes)})`);
    const matchedProject: Project | undefined = DB.projects.find((project) => id === project.id);
    let processingTime = 100;
    let dbOp: (() => any) | undefined = undefined;
    if (matchedProject) {
      if (attributes.title) matchedProject.title = attributes.title;
      if (attributes.running !== undefined) matchedProject.running = attributes.running;
      switch (attributes.action) {
        case 'start':
          processingTime = 3000;
          dbOp = () => DB.executionCycles.push({
            id: DB.executionCycles[DB.executionCycles.length - 1].id + 1,
            startedAt: new Date(),
            threadsCount: 100,
            projectId: id
          });
          break;

        case 'stop':
          processingTime = 3000;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0) return;

            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].responseTime = 234.56;
            DB.executionCycles[index].status = ExecutionCycleStatus.STOPPED;
            DB.executionCycles[index].throughput = 10.24;
          }
          break;

        case 'abort':
          processingTime = 1500;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0) return;

            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].status = ExecutionCycleStatus.ABORTED;
          }
          break;

        case 'terminate':
          processingTime = 3000;
          dbOp = () => {
            const index = DB.executionCycles.findIndex((x) => x.projectId === id && !x.stoppedAt);
            if (index < 0) return;

            DB.executionCycles[index].stoppedAt = new Date();
            DB.executionCycles[index].status = ExecutionCycleStatus.ABORTED;
            matchedProject.running = false;
          }
          break;

        default:
          break;
      }
    }

    return new Promise((resolve, reject) => {
      if (matchedProject) {
        setTimeout(() => {
          if (dbOp) dbOp();
          resolve();
        }, processingTime * SLOW_FACTOR);
      } else {
        setTimeout(() => reject(new Error(`No Project found with id - ${id}`)), 500 * SLOW_FACTOR);
      }
    });
  }

  delete(id: number) {
    console.log(`api ---- ProjectService#delete(${id})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject: Project | undefined = DB.projects.find((project) => id === project.id);
        if (matchedProject) {
          DB.projects = DB.projects.filter((project) => project.id !== matchedProject.id);
          resolve();
        } else {
          reject(new Error(`No project with ID ${id}`))
        }
      }, 300 * SLOW_FACTOR);
    });
  }

  create({title}: {[K in keyof Project]?: Project[K]}): Promise<Project> {
    console.log(`api ---- ProjectService#create(${title})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        if (title) {
          const newProject = {
            id: DB.sys.projectIndex.nextId(),
            autoStop: false,
            code: title.toLowerCase().replace(/\s+/, '-'),
            title,
            running: false
          };

          DB.projects.push(newProject);
          resolve({...newProject});
        } else {
          reject(new Error('Missing attributes: title'));
        }
      }, 100);
    });
  }
}

export class ExecutionCycleService {

  list(projectId: number): Promise<ExecutionCycle[]> {
    console.log(`api ---- ExecutionCycle#list(${projectId})`);
    return new Promise(
      (resolve, reject) => setTimeout(
        () => resolve(DB.executionCycles
          .filter((x) => x.projectId === projectId && x.status !== ExecutionCycleStatus.ABORTED)
          .map((x) => ({...x}))), 300 * SLOW_FACTOR));
  }

  update(executionCycleId: number, projectId: number, attributes: {status?: ExecutionCycleStatus}): Promise<ExecutionCycle> {
    console.log(`api ---- ExecutionCycleService#update(${executionCycleId}, ${projectId}, ${attributes})`);
    const matchedCycle = DB.executionCycles.find((value) => value.id === executionCycleId && value.projectId === projectId);
    return new Promise((resolve, reject) => setTimeout(() => {
      if (matchedCycle) {
        if (attributes.status) matchedCycle.status = attributes.status;
        resolve(matchedCycle);
      } else {
        reject(new Error(`No execution cycle with id: ${executionCycleId}, projectId: ${projectId}`));
      }
    }, 100 * SLOW_FACTOR));
  }
}

export class ReportService {

  list(projectId: number) {
    return new Promise<Report[]>((resolve, reject) =>
      setTimeout(() => resolve(DB.reports.filter((report) => report.projectId === projectId).map((x) => ({...x}))), 700));
  }

  create(projectId: number, executionCycleIds: number[]): Promise<void> {
    console.log(`api ---- ExecutionCycles#report(${projectId}, ${executionCycleIds})`);
    return new Promise((resolve, reject) => setTimeout(() => {
      const project = DB.projects.find((value) => value.id === projectId);
      if (project) {
        const [firstExCid, lastExCid] = executionCycleIds.length === 1 ?
                                        [executionCycleIds[0], undefined] :
                                        [executionCycleIds[0], executionCycleIds[executionCycleIds.length - 1]];
        let title = `${project.code}-${firstExCid}`;
        if (lastExCid) title += `-${lastExCid}`;
        const incrementId = DB.reports[DB.reports.length - 1].id + 1;
        DB.reports.push({id: incrementId, projectId, title});
        resolve();
      } else {
        reject(new Error(`No project with id ${projectId}`));
      }
    }, 3000 * SLOW_FACTOR));
  }
}

export class JtlExportService {
  create(projectId: number, executionCycleIds: number[]): Promise<JtlFile> {
    console.log(`api ---- JtlExportService#create(${projectId}, ${executionCycleIds})`);
    return new Promise((resolve, reject) => setTimeout(() => {
      const project = DB.projects.find((value) => value.id === projectId);
      if (project) {
        const [firstExCid, lastExCid] = executionCycleIds.length === 1 ?
                                        [executionCycleIds[0], undefined] :
                                        [executionCycleIds[0], executionCycleIds[executionCycleIds.length - 1]];
        let title = `${project.code}-${firstExCid}`;
        if (lastExCid) title += `-${lastExCid}`;
        const fileExtn = lastExCid ? 'zip' : 'jtl';
        const fileName = `${title}.${fileExtn}`;
        resolve({title: fileName, url: `http://static.hailstorm.local/${fileName}`});
      } else {
        reject(new Error(`No project with id ${projectId}`));
      }
    }, 3000 * SLOW_FACTOR));
  }
}

export class JMeterService {
  list(projectId: number): Promise<JMeter> {
    console.log(`api ---- JMeterService#list(${projectId})`);
    return new Promise<JMeter>((resolve, reject) => {
      setTimeout(() => {
        resolve({
          files: [
            {id: 1, name: 'prime.jmx', properties: new Map([["foo", "1"]]) },
            {id: 2, name: 'data.csv', dataFile: true },
          ]
        });
      }, 300 * SLOW_FACTOR)
    });
  }

  create(projectId: number, attrs: JMeterFile): Promise<JMeterFile> {
    console.log(`api ---- JMeterService#create(${projectId}, ${attrs})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject = DB.projects.find((value) => value.id === projectId);
        if (matchedProject) {
          if (!matchedProject.jmeter) {
            matchedProject.jmeter = {
              files: []
            }
          }

          const savedAttrs: JMeterFile = {...attrs, id: DB.sys.jmeterIndex.nextId()}
          matchedProject.jmeter.files = [...matchedProject.jmeter.files, savedAttrs];
          resolve(savedAttrs);
        } else {
          reject(new Error(`Did not find project with id: ${projectId}`));
        }
      }, 300 * SLOW_FACTOR);
    });
  }

  update(projectId: number, jmeterFileId: number, attrs: {[K in keyof JMeterFile]?: JMeterFile[K]}): Promise<JMeterFile> {
    console.log(`api ---- JMeterService#update(${projectId}, ${jmeterFileId}), ${attrs}`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject = DB.projects.find((value) => value.id === projectId);
        if (matchedProject) {
          if (!matchedProject.jmeter) {
            reject(new Error('Did not find any JMeter plans to update'));
            return;
          }

          const matchedFile = matchedProject.jmeter!.files.find((value) => value.id === jmeterFileId);
          if (!matchedFile) {
            reject(new Error(`Did not find JMeter file with id: ${jmeterFileId} in project with id: ${projectId}`));
            return;
          }

          matchedFile.properties = attrs.properties;
          resolve(matchedFile);
        } else {
          reject(new Error(`Did not find project with id: ${projectId}`));
        }
      }, 300 * SLOW_FACTOR);
    });
  }

  destroy(projectId: number, jmeterFileId: number) {
    console.log(`api ---- JMeterService#destroy(${projectId}, ${jmeterFileId})`);
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        const matchedProject = DB.projects.find((value) => value.id === projectId);
        if (matchedProject) {
          if (!matchedProject.jmeter) {
            reject(new Error('Did not find any JMeter plans to update'));
            return;
          }

          const matchedFile = matchedProject.jmeter!.files.find((value) => value.id === jmeterFileId);
          if (!matchedFile) {
            reject(new Error(`Did not find JMeter file with id: ${jmeterFileId} in project with id: ${projectId}`));
            return;
          }

          matchedProject.jmeter.files = matchedProject.jmeter.files.filter((value) => value.id !== matchedFile.id);
          resolve();
        } else {
          reject(new Error(`Did not find project with id: ${projectId}`));
        }
      }, 300 * SLOW_FACTOR);
    });
  }
}

export class JMeterValidationService {
  create(attrs: JMeterFileUploadState): Promise<JMeterFileUploadState & {autoStop: boolean}> {
    console.log(`api ---- JMeterValidationService#create(${attrs})`);
    return new Promise<JMeterFileUploadState & {autoStop: boolean}>((resolve, reject) => setTimeout(() => {
      resolve({
        name: attrs.name,
        properties: new Map([
          ["ThreadGroup.Admin.NumThreads", "1"],
          ["ThreadGroup.Users.NumThreads", "10"],
          ["Users.RampupTime", undefined]
        ]),
        autoStop: Date.now() % 2 === 0
      });
    }, 500 * SLOW_FACTOR));
  }
}

export class AWSEC2PricingService {
  list(region: string): Promise<AWSInstanceChoiceOption[]> {
    console.log(`api ---- AWSEC2PricingService#list(${region})`);
    return new Promise<AWSInstanceChoiceOption[]>((resolve, reject) => {
      setTimeout(() => {
        const data = [
          { instanceType: "m5a.large", maxThreadsByInstance: 500, hourlyCostByInstance: 0.096, numInstances: 1 },
          { instanceType: "m5a.xlarge", maxThreadsByInstance: 1000, hourlyCostByInstance: 0.192, numInstances: 1 },
          { instanceType: "m5a.2xlarge", maxThreadsByInstance: 2000, hourlyCostByInstance: 0.3440, numInstances: 1 },
          { instanceType: "m5a.4xlarge", maxThreadsByInstance: 5000, hourlyCostByInstance: 0.6880, numInstances: 1 },
          { instanceType: "m5a.8xlarge", maxThreadsByInstance: 10000, hourlyCostByInstance: 1.3760, numInstances: 1 },
          { instanceType: "m5a.12xlarge", maxThreadsByInstance: 15000, hourlyCostByInstance: 2.0640, numInstances: 1 },
          { instanceType: "m5a.16xlarge", maxThreadsByInstance: 20000, hourlyCostByInstance: 2.7520, numInstances: 1 },
          { instanceType: "m5a.24xlarge", maxThreadsByInstance: 30000, hourlyCostByInstance: 4.1280, numInstances: 1 },
        ]
        .map((attrs) => new AWSInstanceChoiceOption(attrs));
        resolve(data);
      }, 500 * SLOW_FACTOR);
    });
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
        const awsCluster: AmazonCluster = {
          id: 223, accessKey: 'A', secretKey: 'S', code: 'aws-223', instanceType: 't2.small', maxThreadsByInstance: 25,
          region: 'us-east-1', title: 'AWS us-east-1', type: 'AWS'
        }

        resolve([awsCluster]);
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
