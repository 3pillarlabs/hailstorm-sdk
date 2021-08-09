import React from 'react';
import { mount } from 'enzyme';
import { ClusterConfiguration } from './ClusterConfiguration';
import { AppState } from '../store';
import { WizardTabTypes } from '../NewProjectWizard/domain';
import { AppStateContext } from '../appStateContext';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { ClusterService } from "../services/ClusterService";
import { AWSRegionService } from "../services/AWSRegionService";
import { AWSEC2PricingService } from "../services/AWSEC2PricingService";
import { render as renderComponent, fireEvent, wait} from '@testing-library/react';
import { AmazonCluster, Cluster, DataCenterCluster, ExecutionCycleStatus } from '../domain';
import { ClusterSetupCompletedAction } from '../NewProjectWizard/actions';
import { RemoveClusterAction, ActivateClusterAction } from './actions';
import { AppNotificationContextProps } from '../app-notifications';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider/AppNotificationProvider';

describe('<ClusterConfiguration />', () => {
  let appState: AppState;
  let fetchPricing: Promise<AWSInstanceChoiceOption[]>;
  let fetchRegions: Promise<AWSRegionList>;
  const dispatch = jest.fn();

  beforeEach(() => {
    jest.resetAllMocks();
  });

  beforeEach(() => {
    appState = {
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        autoStop: true,
        running: false,
        jmeter: {
          files: [
            { id: 10, name: 'a.jmx', properties: new Map([["foo", "10"]]) },
            { id: 11, name: 'a.csv', dataFile: true }
          ]
        },
        clusters: []
      },

      runningProjects: [],

      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true
        },
        activeJMeterFile: { id: 10, name: 'a.jmx', properties: new Map([["foo", "10"]]) }
      }
    }
  });

  beforeEach(() => {
    fetchRegions = Promise.resolve<AWSRegionList>({
      regions: [
        {
          code: 'North America',
          title: 'North America',
          regions: [
            { code: 'us-east-1', title: 'Ohio, US East' }
          ]
        }
      ],

      defaultRegion: { code: 'us-east-1', title: 'Ohio, US East' }
    });

    jest.spyOn(AWSRegionService.prototype, 'list').mockReturnValue(fetchRegions);
  });

  beforeEach(() => {
    fetchPricing = Promise.resolve([
      new AWSInstanceChoiceOption({
        instanceType: 'm3a.small', numInstances: 1, maxThreadsByInstance: 500, hourlyCostByInstance: 0.092
      })
    ]);

    jest.spyOn(AWSEC2PricingService.prototype, 'list').mockReturnValue(fetchPricing);
  });

  function createComponent(notifiers?: {[K in keyof AppNotificationContextProps]: AppNotificationContextProps[K]}) {
    const props: AppNotificationContextProps = {
      notifySuccess: jest.fn(),
      notifyInfo: jest.fn(),
      notifyWarning: jest.fn(),
      notifyError: jest.fn(),
      ...notifiers
    };

    return (
      <AppStateContext.Provider value={{appState, dispatch}}>
        <AppNotificationProviderWithProps {...{...props}}>
          <ClusterConfiguration />
        </AppNotificationProviderWithProps>
      </AppStateContext.Provider>
    );
  }

  function mockClusterList(list: AmazonCluster[]) {
    const listPromise: Promise<AmazonCluster[]> = Promise.resolve(list);
    return [jest.spyOn(ClusterService.prototype, 'list').mockReturnValue(listPromise), listPromise];
  }

  it('should render without crashing', async () => {
    delete appState.activeProject!.clusters;
    const [spy, listPromise] = mockClusterList([{
      accessKey: 'A', instanceType: 't2.small', maxThreadsByInstance: 25, region: 'us-east-1', secretKey: 's',
      title: 'aws-us-east-1', type: "AWS", code: 'aws-223', id: 223
    } as AmazonCluster]);
    const component = mount(createComponent());
    component.update();
    await listPromise;
    expect(spy).toBeCalled();
  });

  describe('when no clusters have been added', () => {
    it('should disable Next button', () => {
      const component = mount(createComponent());
      const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
      expect(nextButton).toBeDisabled();
    });
  });

  describe('when no cluster is active', () => {
    it('should show empty message', async () => {
      delete appState.activeProject!.clusters;
      const [spy, listPromise] = mockClusterList([]);
      const component = mount(createComponent());
      component.update();
      await listPromise;
      expect(spy).toBeCalled();
      component.update();
      expect(component.text()).toMatch(/no clusters yet/i);
    });

    it('should show cluster options', () => {
      const component = mount(createComponent());
      expect(component.find('a').findWhere((wrapper) => wrapper.text().match(/aws/i) !== null).at(0)).toExist();
      expect(component.find('a').findWhere((wrapper) => wrapper.text().match(/data center/i) !== null).at(0)).toExist();
      expect(component.find('ClusterChoice a').findWhere((wrapper) => wrapper.text().match(/cancel/i) !== null).at(0)).not.toExist();
    });

    it('should disable add cluster button', () => {
      const component = mount(createComponent());
      expect(component.find('button[role="Add Cluster"]')).toBeDisabled();
    });

    it('should show AWS form if AWS is chosen', () => {
      const component = mount(createComponent());
      const awsLink = component.find('ClusterChoice').find('a').findWhere((wrapper) => wrapper.text().match(/aws/i) !== null).at(0);
      awsLink.simulate('click');
      component.update();
      expect(dispatch).toBeCalled();
      appState.wizardState!.activeCluster = {title: '', type: 'AWS'};
      component.setProps({value: {appState, dispatch}});
      component.update();
      expect(component).toContainExactlyOneMatchingElement('AWSForm');
    });

    it('should show data center form when data center is chosen', () => {
      const component = mount(createComponent());
      const dataCenterLink = component
        .find('ClusterChoice')
        .find('a')
        .findWhere((wrapper) => wrapper.text().match(/data center/i) !== null)
        .at(0);
      dataCenterLink.simulate('click');
      component.update();
      expect(dispatch).toBeCalled();
      appState.wizardState!.activeCluster = {title: '', type: 'DataCenter'};
      component.setProps({value: {appState, dispatch}});
      component.update();
      expect(component).toContainExactlyOneMatchingElement('DataCenterForm');
    });
  });

  describe('when a cluster is active', () => {
    it('should remove an active cluster', async () => {
      appState.wizardState!.activeCluster = {title: '', type: 'AWS'};
      delete appState.activeProject!.clusters;
      const [spy, listPromise] = mockClusterList([]);
      const component = mount(createComponent());
      component.update();
      await listPromise;
      expect(spy).toBeCalled();
      component.update();
      const remove = component.find('button[role="Remove Cluster"]');
      remove.simulate('click');
      expect(dispatch).toBeCalled();
      appState.wizardState!.activeCluster = undefined;
      component.setProps({value: {appState, dispatch}});
      component.update();
      await listPromise;
      expect(component.text()).toMatch(/no clusters yet/i);
    });
  });

  describe('when aws cluster is chosen', () => {
    beforeEach(() => {
      appState.wizardState!.activeCluster = {title: '', type: 'AWS'};
    });

    it('should disable Add Cluster button', () => {
      const component = mount(createComponent());
      expect(component.find('button[role="Add Cluster"]')).toBeDisabled();
    });

    it('should show AWS form', () => {
      const component = mount(createComponent());
      expect(component).toContainExactlyOneMatchingElement('AWSForm');
    });

  });

  describe('when a cluster is added', () => {
    let savedCluster: AmazonCluster;
    beforeEach(() => {
      savedCluster = {
        id: 23,
        code: 'singing-penguin-23',
        title: '',
        type: 'AWS',
        accessKey: 'A',
        secretKey: 'S',
        region: 'us-east-1',
        instanceType: 'm3a.small',
        maxThreadsByInstance: 500
      };

      appState.wizardState!.activeCluster = savedCluster;
      appState.activeProject!.clusters = [ savedCluster ];
    });

    it('should show added cluster in list', () => {
      const component = mount(createComponent());
      const clusterList = component.find('ClusterList');
      expect(clusterList).toExist();
      expect(clusterList.prop('clusters')).toEqual(appState.activeProject!.clusters);
    });

    it('should remove the cluster from list', async () => {
      const destroyPromise = Promise.resolve();
      const destroySpy = jest.spyOn(ClusterService.prototype, 'destroy').mockReturnValue(destroyPromise);
      const {findByRole} = renderComponent(createComponent());
      const remove = await findByRole('Remove Cluster');
      fireEvent.click(remove);
      expect(destroySpy).toBeCalled();
      await destroyPromise;
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[0][0]).toBeInstanceOf(RemoveClusterAction);
    });

    it('should enable Add Cluster', async () => {
      const {findByRole} = renderComponent(createComponent());
      const add = await findByRole('Add Cluster');
      expect(add.getAttribute("disabled")).toBeFalsy();
    });

    it('should open cluster choice to add a cluster', async () => {
      const {findByRole} = renderComponent(createComponent());
      const add = await findByRole('Add Cluster');
      fireEvent.click(add);
      expect(dispatch).toBeCalled();
    });

    it('should cancel the open cluster choice', async () => {
      appState.wizardState!.activeCluster = undefined;
      const {findByRole} = renderComponent(createComponent());
      const cancel = await findByRole('Cancel Choice');
      fireEvent.click(cancel);
      expect(dispatch).toBeCalled();
    });

    it('should select a cluster from the list', () => {
      const component = mount(createComponent());
      const clusterList = component.find('ClusterList');
      const onSelectCluster = clusterList.prop('onSelectCluster') as (cluster: Cluster) => void;
      onSelectCluster(savedCluster);
      expect(dispatch).toBeCalled();
    });

    it('should move to the review tab on next', async () => {
      const {findByText} = renderComponent(createComponent());
      const nextButton = await findByText('Next');
      fireEvent.click(nextButton);
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[0][0]).toBeInstanceOf(ClusterSetupCompletedAction);
    });

    it('should disable a cluster with existing tests', async () => {
      savedCluster.clientStatsCount = 3;
      const updatePromise = Promise.resolve(savedCluster);
      const destroySpy = jest.spyOn(ClusterService.prototype, 'update').mockReturnValue(updatePromise);
      const {findByRole} = renderComponent(createComponent());
      const remove = await findByRole('Disable Cluster');
      expect(remove.textContent).toMatch(/disable/i);
      fireEvent.click(remove);
      expect(destroySpy).toBeCalled();
      await updatePromise;
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[0][0]).toBeInstanceOf(RemoveClusterAction);
    });

    it('should enable a disabled cluster', async () => {
      savedCluster.loadAgentsCount = 1;
      const updatePromise = Promise.resolve({...savedCluster});
      const updateApiSpy = jest.spyOn(ClusterService.prototype, 'update').mockReturnValue(updatePromise);
      savedCluster.disabled = true;
      const {findByRole} = renderComponent(createComponent());
      const enable = await findByRole('Enable Cluster');
      fireEvent.click(enable);
      await updatePromise;
      expect(updateApiSpy).toBeCalledWith(1, 23, { disabled: false });
      expect(dispatch).toBeCalled();
      expect(dispatch.mock.calls[0][0]).toBeInstanceOf(ActivateClusterAction);
    });

    it('should show the cluster in edit mode', () => {
      const component = mount(createComponent());
      expect(component).toContainExactlyOneMatchingElement('EditAWSCluster');
    });
  });

  describe('when data center cluster is chosen', () => {
    beforeEach(() => {
      appState.wizardState!.activeCluster = {title: '', type: 'DataCenter'};
    });

    it('should show DataCenterForm', () => {
      const component = mount(createComponent());
      expect(component).toContainExactlyOneMatchingElement('DataCenterForm');
    });
  });

  describe('when a data center cluster is active', () => {
    beforeEach(() => {
      appState.wizardState!.activeCluster = {
        id: 42,
        title: 'Cluster One',
        code: 'rising-star-23',
        sshIdentity: {name: 'secure.pem'},
        sshPort: 22,
        type: 'DataCenter',
        userName: 'ubuntu',
        machines: ['servo']
      } as DataCenterCluster;
    });

    it('should show a created cluster', () => {
      const component = mount(createComponent());
      expect(component).toContainExactlyOneMatchingElement('DataCenterView');
    });
  });
});
