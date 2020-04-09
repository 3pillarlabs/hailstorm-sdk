import { computeChoice } from './AWSInstanceCalculator';
import { AWSInstanceChoiceOption } from './domain';

describe('AWSInstanceCalculator', () => {
  for (const dataPoint of [
    {numUsers: 50, numInstances: 1, instanceType: "m5a.large"},
    {numUsers: 500, numInstances: 1, instanceType: "m5a.large"},
    {numUsers: 600, numInstances: 1, instanceType: 'm5a.xlarge'},
    {numUsers: 1000, numInstances: 1, instanceType: 'm5a.xlarge'},
    {numUsers: 2000, numInstances: 1, instanceType: 'm5a.2xlarge'},
    {numUsers: 5000, numInstances: 1, instanceType: 'm5a.4xlarge'},
    {numUsers: 10000, numInstances: 1, instanceType: 'm5a.8xlarge'},
    {numUsers: 15000, numInstances: 1, instanceType: 'm5a.12xlarge'},
    {numUsers: 20000, numInstances: 1, instanceType: 'm5a.16xlarge'},
    {numUsers: 30000, numInstances: 1, instanceType: 'm5a.24xlarge'},
    {numUsers: 40000, numInstances: 2, instanceType: 'm5a.16xlarge'},
    {numUsers: 50000, numInstances: 5, instanceType: 'm5a.8xlarge'},
    {numUsers: 60000, numInstances: 2, instanceType: 'm5a.24xlarge'},
    {numUsers: 70000, numInstances: 7, instanceType: 'm5a.8xlarge'},
    {numUsers: 80000, numInstances: 4, instanceType: 'm5a.16xlarge'},
    {numUsers: 90000, numInstances: 9, instanceType: 'm5a.8xlarge'},
    {numUsers: 100000,numInstances: 5, instanceType: 'm5a.16xlarge'},
    {numUsers: 200000,numInstances: 10, instanceType: 'm5a.16xlarge'},
    {numUsers: 500000,numInstances: 17, instanceType: 'm5a.24xlarge'},
    {numUsers: 600000,numInstances: 20, instanceType: 'm5a.24xlarge'},
  ]) {
    it(`should compute choices at max users at ${dataPoint}`, () => {
      const choice = computeChoice(dataPoint.numUsers, [
          { instanceType: "m5a.large", maxThreadsByInstance: 500, hourlyCostByInstance: 0.096, numInstances: 1 },
          { instanceType: "m5a.xlarge", maxThreadsByInstance: 1000, hourlyCostByInstance: 0.192, numInstances: 1 },
          { instanceType: "m5a.2xlarge", maxThreadsByInstance: 2000, hourlyCostByInstance: 0.3440, numInstances: 1 },
          { instanceType: "m5a.4xlarge", maxThreadsByInstance: 5000, hourlyCostByInstance: 0.6880, numInstances: 1 },
          { instanceType: "m5a.8xlarge", maxThreadsByInstance: 10000, hourlyCostByInstance: 1.3760, numInstances: 1 },
          { instanceType: "m5a.12xlarge", maxThreadsByInstance: 15000, hourlyCostByInstance: 2.0640, numInstances: 1 },
          { instanceType: "m5a.16xlarge", maxThreadsByInstance: 20000, hourlyCostByInstance: 2.7520, numInstances: 1 },
          { instanceType: "m5a.24xlarge", maxThreadsByInstance: 30000, hourlyCostByInstance: 4.1280, numInstances: 1 },
        ]
        .map((attrs) => new AWSInstanceChoiceOption(attrs)));

      expect([
        choice.instanceType,
        choice.numInstances
      ]).toEqual([dataPoint.instanceType, dataPoint.numInstances]);
    });
  }
});
