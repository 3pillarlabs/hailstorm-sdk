import { AWSInstanceChoiceOption } from "./domain";

export function lowestCostOption(pricingData: AWSInstanceChoiceOption[]) {
  return pricingData[0];
}

export function computeChoice(
  numThreads: number,
  pricingData: AWSInstanceChoiceOption[],
  maxInstancesPerCluster: number = AWSInstanceChoiceOption.DEFAULT_MAX_INSTANCES_PER_CLUSTER
) {
  const lessThanMatch = pricingData.find((value) => numThreads <= value.maxThreadsByInstance);
  if (lessThanMatch) return lessThanMatch;

  const viableOptions = pricingData.map((option) => {
    const numInstances = numThreads % option.maxThreadsByInstance === 0 ?
      Math.trunc(numThreads / option.maxThreadsByInstance) :
      Math.trunc(numThreads / option.maxThreadsByInstance) + 1;

    return new AWSInstanceChoiceOption({...option, numInstances});

  }).filter((option) => option.numInstances <= maxInstancesPerCluster);

  const [
    _minCost,
    _minNumInstances,
    choice
  ]: [
    number,
    number,
    AWSInstanceChoiceOption
  ] = viableOptions.reduce(([minCost, minNumInstances, choice], option) => {
    if (minCost >= option.hourlyCostByCluster() && minNumInstances > option.numInstances) {
      return [option.hourlyCostByCluster(), option.numInstances, option];
    }

    return [minCost, minNumInstances, choice];
  }, [1000000, maxInstancesPerCluster + 1, pricingData[pricingData.length - 1]]);

  return choice;
}

export function maxThreadsByCluster(
  pricingData: AWSInstanceChoiceOption[],
  maxInstancesPerCluster: number = AWSInstanceChoiceOption.DEFAULT_MAX_INSTANCES_PER_CLUSTER
) {
  return pricingData.reduce(
    (max, value) => max < value.maxThreadsByInstance ? value.maxThreadsByInstance : max, -1
  ) * maxInstancesPerCluster;
}
