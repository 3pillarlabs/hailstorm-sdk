import React from 'react';
import { AppState, Action } from '../store';
import { AmazonCluster, DataCenterCluster } from '../domain';
import { WizardTabTypes } from './domain';
import { render } from '@testing-library/react';
import { SummaryView } from './SummaryView';
import { AppStateContext } from '../appStateContext';
import { mount } from 'enzyme';
import { ReviewCompletedAction } from './actions';

describe('<SummaryView />', () => {
  const appState: AppState = {
    runningProjects: [],
    activeProject: {
      id: 8,
      code: 'sphynx',
      title: 'Sphynx',
      running: false,
      jmeter: {
        files: [
          {
            name: 'testdroid_simple.jmx',
            id: 4,
            properties: new Map([
              ["ThreadGroup.Admin.NumThreads", "1"],
              ["ThreadGroup.Users.NumThreads", "10"],
              ["Users.RampupTime", "0"]
            ])
          },
          {
            id: 5,
            name: 'testdroid_accounts.csv',
            dataFile: true
          }
        ]
      },
      clusters: [
        {
          type: 'AWS',
          id: 23,
          code: 'silver-lining-231',
          title: 'AWS us-east-1',
          accessKey: 'A',
          instanceType: 'm3a.large',
          maxThreadsByInstance: 500,
          region: 'us-east-1',
          secretKey: 's',
          vpcSubnetId: 'subnet-123456'
        } as AmazonCluster,
        {
          type: 'DataCenter',
          id: 42,
          code: 'happy-penguin-345',
          title: 'RAC 1',
          userName: 'fedora',
          sshIdentity: {name: 'secure.pem'},
          sshPort: 22,
          machines: ['frodo', 'sam']
        } as DataCenterCluster
      ]
    },
    wizardState: {
      activeTab: WizardTabTypes.Review,
      done: {
        [WizardTabTypes.Project]: true,
        [WizardTabTypes.JMeter]: true,
        [WizardTabTypes.Cluster]: true
      },
      activeJMeterFile: {
        name: 'testdroid_simple.jmx',
        id: 4,
        properties: new Map([
          ["ThreadGroup.Admin.NumThreads", "1"],
          ["ThreadGroup.Users.NumThreads", "10"],
          ["Users.RampupTime", "0"]
        ])
      },
      activeCluster: {
        type: 'AWS',
        id: 23,
        code: 'silver-lining-231',
        title: 'AWS us-east-1',
        accessKey: 'A',
        instanceType: 'm3a.large',
        maxThreadsByInstance: 500,
        region: 'us-east-1',
        secretKey: 's',
        vpcSubnetId: 'subnet-123456'
      } as AmazonCluster
    }
  };

  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    render(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <SummaryView />
      </AppStateContext.Provider>
    );
  });

  it('should jump to from a section to a tab for editing', () => {
    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <SummaryView />
      </AppStateContext.Provider>
    );

    component.find('JMeterSection a').simulate('click');
    expect(dispatch).toBeCalled();
    let action: Action = dispatch.mock.calls[0][0];
    expect(action.payload).toEqual(WizardTabTypes.JMeter);

    component.find('JMeterSection a').simulate('click');
    expect(dispatch).toBeCalledTimes(2);
    action = dispatch.mock.calls[1][0];
    expect(action.payload).toEqual(WizardTabTypes.JMeter);
  });

  it('should redirect to workspace on completing review', () => {
    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <SummaryView />
      </AppStateContext.Provider>
    );

    component.find('StepFooter button').simulate('click');
    expect(dispatch).toBeCalled();
    expect(dispatch.mock.calls[0][0]).toBeInstanceOf(ReviewCompletedAction);
  });
});
