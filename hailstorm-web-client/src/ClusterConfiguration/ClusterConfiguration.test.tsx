import React from 'react';
import { render, mount } from 'enzyme';
import { ClusterConfiguration } from './ClusterConfiguration';
import { AppState } from '../store';
import { WizardTabTypes } from '../NewProjectWizard/domain';
import { AppStateContext } from '../appStateContext';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { AWSEC2PricingService, AWSRegionService, ClusterService } from '../api';
import { render as renderComponent, fireEvent, wait} from '@testing-library/react';
import { AmazonCluster, Cluster } from '../domain';

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
        }
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

  function createComponent() {
    return (
      <AppStateContext.Provider value={{appState, dispatch}}>
        <ClusterConfiguration />
      </AppStateContext.Provider>
    );
  }

  it('should render without crashing', () => {
    render(createComponent());
  });

  describe('when no clusters have been added', () => {
    it('should disable Next button', () => {
      const component = mount(createComponent());
      const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
      expect(nextButton).toBeDisabled();
    });
  });

  describe('when no cluster is active', () => {
    it('should show empty message', () => {
      const component = mount(createComponent());
      expect(component.text()).toMatch(/no clusters yet/i);
    });

    it('should show cluster options', () => {
      const component = mount(createComponent());
      expect(component.find('a').findWhere((wrapper) => wrapper.text().match(/aws/i) !== null).at(0)).toExist();
      expect(component.find('a').findWhere((wrapper) => wrapper.text().match(/data center/i) !== null).at(0)).toExist();
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

    test.todo('should show data center form when data center is chosen');
  });

  describe('when aws cluster is chosen', () => {
    beforeEach(() => {
      appState.wizardState!.activeCluster = {title: '', type: 'AWS'};
    });

    it('should disable Add Cluster button', () => {
      const component = mount(createComponent());
      expect(component.find('button[role="Add Cluster"]')).toBeDisabled();
    });

    it('should show form fields', () => {
      const component = mount(createComponent());
      expect(component).toContainExactlyOneMatchingElement('input[name="accessKey"]');
      expect(component).toContainExactlyOneMatchingElement('input[name="secretKey"]');
      expect(component).toContainExactlyOneMatchingElement('input[name="vpcSubnetId"]');
    });

    it('should show control for instance specifications', async () => {
      const component = mount(createComponent());
      await fetchRegions;
      await fetchPricing;
      component.update();
      expect(component).toContainExactlyOneMatchingElement('AWSInstanceChoice');
    });

    it('should show estimated cost based on defaults', async () => {
      const {findByText} = renderComponent(createComponent());
      await fetchRegions;
      await fetchPricing;
      const message = await findByText(/Estimated Hourly Cost/i);
      expect(message).toBeDefined();
    });

    it('should show control for AWS region', () => {
      const component = mount(createComponent());
      expect(component).toContainExactlyOneMatchingElement('AWSRegionChoice');
    });

    it('should remove an active cluster', () => {
      const component = mount(createComponent());
      const remove = component.find('button[role="Remove Cluster"]');
      remove.simulate('click');
      expect(dispatch).toBeCalled();
      appState.wizardState!.activeCluster = undefined;
      component.setProps({value: {appState, dispatch}});
      expect(component.text()).toMatch(/no clusters yet/i);
    });

    it('should validate cluster inputs', async () => {
      const {findByText, findByTestId, findAllByText} = renderComponent(createComponent());
      await fetchRegions;
      await fetchPricing;
      await findByText(/Estimated Hourly Cost/i);
      const form = await findByTestId('AWSForm');
      fireEvent.submit(form);
      expect(dispatch).not.toBeCalled();
      const messages = await findAllByText(/blank/i);
      expect(messages.length).toEqual(2);
    });

    it('should save the cluster', async () => {
      const savedCluster: AmazonCluster = {
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

      const createdCluster = Promise.resolve<Cluster>(savedCluster);
      const createSpy = jest.spyOn(ClusterService.prototype, 'create').mockReturnValue(createdCluster);
      const {findByTestId, findByText} = renderComponent(createComponent());
      await fetchRegions;
      await fetchPricing;
      await findByText(/Estimated Hourly Cost/i);
      const accessKey = await findByTestId('AWS Access Key');
      const secretKey = await findByTestId('AWS Secret Key');
      fireEvent.change(accessKey, {target: {value: savedCluster.accessKey}});
      fireEvent.change(secretKey, {target: {value: savedCluster.secretKey}});
      const save = await findByText(/save/i);
      fireEvent.click(save);
      await createdCluster;
      await wait();

      expect(createSpy).toBeCalled();
      expect(dispatch).toBeCalled();
      const action = dispatch.mock.calls[0][0] as {payload: Cluster};
      expect(action.payload).toEqual(savedCluster);
    });
  });

  describe('given a cluster is added', () => {
    beforeEach(() => {
      const savedCluster: AmazonCluster = {
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
    });
  });
});
