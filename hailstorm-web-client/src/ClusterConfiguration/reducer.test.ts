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

  it('should set Cluster configuration in the new project wizard', () => {
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

    state.wizardState!.reloadTab = true;
    const nextState = reducer(state, new SetClusterConfigurationAction([savedCluster]));
    expect(nextState.wizardState!.activeCluster).toEqual(savedCluster);
    expect(nextState.wizardState!.reloadTab).toBeUndefined();
  });

  it('should set Cluster configuration in the project workspace', () => {
    const state = initialState();
    delete state.wizardState;
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

  it('should mark a completed project as modified if a cluster is removed', () => {
    const cluster: Cluster = { id: 23, type: 'DataCenter', title: 'RACK 1' };
    const jmeterFile = { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) };
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        clusters: [ cluster ],
        jmeter: {
          files: [ jmeterFile ]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true
        },
        activeCluster: { ...cluster },
        activeJMeterFile: jmeterFile
      }
    }, new RemoveClusterAction({...cluster}));

    expect(nextState.wizardState!.modifiedAfterReview).toBeTruthy();
  });

  it('should mark a project as incomplete when the last cluster is removed', () => {
    const cluster: Cluster = { id: 23, type: 'DataCenter', title: 'RACK 1' };
    const jmeterFile = { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) };
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        clusters: [ cluster ],
        jmeter: {
          files: [ jmeterFile ]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true
        },
        activeCluster: { ...cluster },
        activeJMeterFile: jmeterFile
      }
    }, new RemoveClusterAction({...cluster}));

    expect(nextState.activeProject!.incomplete).toBeTruthy();
  });

  it('should mark a completed project as modified if a cluster is added', () => {
    const cluster: Cluster = { id: 23, type: 'DataCenter', title: 'RACK 1' };
    const jmeterFile = { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) };
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        jmeter: {
          files: [ jmeterFile ]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true
        },
        activeJMeterFile: jmeterFile
      }
    }, new SaveClusterAction(cluster));

    expect(nextState.wizardState!.modifiedAfterReview).toBeTruthy();
  });

  it('should disable a cluster', () => {
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
    let nextState = reducer(state, new RemoveClusterAction({...savedCluster, disabled: true}));
    expect(nextState.activeProject!.clusters!.length).toEqual(2);
    expect(nextState.activeProject!.clusters![0]).toEqual({...savedCluster, disabled: true});
    expect(nextState.activeProject!.clusters![1]).toEqual(anotherCluster);
  });

  it('should enable a cluster', () => {
    const state = initialState();
    const cluster: AmazonCluster = {
      title: '',
      type: 'AWS',
      accessKey: 'A',
      secretKey: 'S',
      region: 'us-east-1',
      instanceType: 'm3a.small',
      maxThreadsByInstance: 500,
      id: 23,
      code: 'singing-penguin-23',
      disabled: true
    };

    state.activeProject!.clusters = [cluster];

    const payload = {...cluster, disabled: false};
    const nextState = reducer(state, new ActivateClusterAction(payload));
    expect(nextState.activeProject!.clusters!.length).toEqual(1);
    expect(nextState.wizardState!.activeCluster!.disabled).toBeUndefined();
  });

  it('should mark project as incomplete if last cluster is disabled', () => {
    const cluster: Cluster = { id: 23, type: 'DataCenter', title: 'RACK 1' };
    const jmeterFile = { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) };
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        clusters: [ cluster ],
        jmeter: {
          files: [ jmeterFile ]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true
        },
        activeCluster: { ...cluster },
        activeJMeterFile: jmeterFile
      }
    }, new RemoveClusterAction({...cluster, disabled: true}));

    expect(nextState.activeProject!.incomplete).toBeTruthy();
  });
});
