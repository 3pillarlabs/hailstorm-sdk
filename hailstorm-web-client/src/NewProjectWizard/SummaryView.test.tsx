import React from 'react';
import { AppState, Action } from '../store';
import { AmazonCluster, DataCenterCluster } from '../domain';
import { WizardTabTypes } from './domain';
import { render } from '@testing-library/react';
import { SummaryView } from './SummaryView';
import { mount } from 'enzyme';
import { ReviewCompletedAction } from './actions';
import { AppNotificationProvider } from '../AppNotificationProvider';
import { AppStateProviderWithProps } from '../AppStateProvider';

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
          },
          {
            name: 'a.jmx',
            id: 6,
            properties: new Map([
              ["NumThreads", "10"]
            ]),
            disabled: true
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
      <AppStateProviderWithProps {...{appState, dispatch: jest.fn()}}>
        <SummaryView />
      </AppStateProviderWithProps>
    );
  });

  it('should jump to from a section to a tab for editing', () => {
    const dispatch = jest.fn();
    const component = mount(
      <AppStateProviderWithProps {...{appState, dispatch}}>
        <SummaryView />
      </AppStateProviderWithProps>
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
      <AppNotificationProvider>
        <AppStateProviderWithProps {...{appState, dispatch}}>
          <SummaryView />
        </AppStateProviderWithProps>
      </AppNotificationProvider>
    );

    component.find('StepFooter button').simulate('click');
    expect(dispatch).toBeCalled();
    expect(dispatch.mock.calls[0][0]).toBeInstanceOf(ReviewCompletedAction);
  });

  it('should not show disabled test plans', () => {
    const component = mount(
      <AppStateProviderWithProps {...{appState, dispatch: jest.fn()}}>
        <SummaryView />
      </AppStateProviderWithProps>
    );

    expect(component.text()).not.toMatch(/a\.jmx/);
  });
});
