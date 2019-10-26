import { reducer } from './reducer';
import { NewProjectWizardState, WizardTabTypes } from '../NewProjectWizard/domain';
import { ActivateClusterAction, RemoveClusterAction, SaveClusterAction, SetClusterConfigurationAction, ChooseClusterOptionAction } from './actions';
import { Cluster, AmazonCluster } from '../domain';

describe('reducer', () => {
  const initialState: () => NewProjectWizardState = () => ({
    activeProject: {
      id: 1,
      code: 'a',
      title: 'A',
      running: false,
      autoStop: true,
      jmeter: {
        files: [
          {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])},
          {id: 101, name: 'a.csv', dataFile: true}
        ]
      }
    },

    wizardState: {
      activeTab: WizardTabTypes.Cluster,
      done: {
        [WizardTabTypes.Project]: true,
        [WizardTabTypes.JMeter]: true
      },
      activeJMeterFile: {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])}
    }
  });

  it('should activate new AWS cluster', () => {
    const payload: Cluster = {title: '', type: 'AWS'};
    const nextState = reducer(initialState(), new ActivateClusterAction(payload));
    expect(nextState.wizardState!.activeCluster).toEqual(payload);
  });

  it('should remove active cluster', () => {
    const state = initialState();
    state.wizardState!.activeCluster = {title: '', type: 'AWS'};
    const nextState = reducer(state, new RemoveClusterAction());
    expect(nextState.wizardState!.activeCluster).toBeUndefined();
  });

  it('should add a cluster', () => {
    const state = initialState();
    state.wizardState!.activeCluster = {title: '', type: 'AWS'};
    const savedCluster: AmazonCluster = {
      title: '',
      type: 'AWS',
      accessKey: 'A',
      secretKey: 'S',
      region: 'us-east-1',
      instanceType: 'm3a.small',
      maxThreadsByInstance: 500,
      id: 23,
      code: 'singing-penguin-23'
    };

    const nextState = reducer(state, new SaveClusterAction(savedCluster));
    expect(nextState.wizardState!.activeCluster).toEqual(savedCluster);
    expect(nextState.activeProject!.clusters!.length).toEqual(1);
    expect(nextState.activeProject!.clusters![0]).toEqual(savedCluster);
  });

  it('should set Cluster configuration', () => {
    const state = initialState();
    const savedCluster: AmazonCluster = {
      title: '',
      type: 'AWS',
      accessKey: 'A',
      secretKey: 'S',
      region: 'us-east-1',
      instanceType: 'm3a.small',
      maxThreadsByInstance: 500,
      id: 23,
      code: 'singing-penguin-23'
    };

    const nextState = reducer(state, new SetClusterConfigurationAction([savedCluster]));
    expect(nextState.activeProject!.clusters!.length).toEqual(1);
    expect(nextState.activeProject!.clusters![0]).toEqual(savedCluster);
  });

  it('should remove an existing cluster', () => {
    const state = initialState();
    const savedCluster: AmazonCluster = {
      title: '',
      type: 'AWS',
      accessKey: 'A',
      secretKey: 'S',
      region: 'us-east-1',
      instanceType: 'm3a.small',
      maxThreadsByInstance: 500,
      id: 23,
      code: 'singing-penguin-23'
    };

    const anotherCluster: AmazonCluster = {...savedCluster, id: 24, region: 'us-west-1'};
    state.activeProject!.clusters = [savedCluster,  anotherCluster];
    let nextState = reducer(state, new RemoveClusterAction(savedCluster));
    expect(nextState.activeProject!.clusters!.length).toEqual(1);
    expect(nextState.activeProject!.clusters![0]).toEqual(anotherCluster);
    nextState = reducer(nextState, new RemoveClusterAction(anotherCluster));
    expect(nextState.activeProject!.clusters).toBeUndefined();
  });

  it('should show option to choose cluster', () => {
    const state = initialState();
    state.wizardState!.activeCluster = {
      title: '',
      type: 'AWS',
      accessKey: 'A',
      secretKey: 'S',
      region: 'us-east-1',
      instanceType: 'm3a.small',
      maxThreadsByInstance: 500,
      id: 23,
      code: 'singing-penguin-23'
    } as AmazonCluster;

    const nextState = reducer(state, new ChooseClusterOptionAction());
    expect(nextState.wizardState!.activeCluster).toBeUndefined();
  });

  it('should activate first cluster in list when no payload is passed', () => {
    const cluster: AmazonCluster = {
      title: '',
      type: 'AWS',
      accessKey: 'A',
      secretKey: 'S',
      region: 'us-east-1',
      instanceType: 'm3a.small',
      maxThreadsByInstance: 500,
      id: 23,
      code: 'singing-penguin-23'
    };

    const state = initialState();
    state.activeProject!.clusters = [ cluster ];

    const nextState = reducer(state, new ActivateClusterAction());
    expect(nextState.wizardState!.activeCluster).toEqual(cluster);
  });
});
