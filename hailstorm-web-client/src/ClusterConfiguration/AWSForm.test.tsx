import React from 'react';
import { AmazonCluster, Cluster, Project } from '../domain';
import { AWSForm } from './AWSForm';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { AWSEC2PricingService } from '../services/AWSEC2PricingService';
import { act, fireEvent, render, wait } from '@testing-library/react';
import { AWSRegionService } from '../services/AWSRegionService';
import { mount } from 'enzyme';
import { ClusterService } from '../services/ClusterService';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider';
import { AppNotificationContextProps } from '../app-notifications';

describe('<AWSForm />', () => {
  const activeProject: Project = {
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
  };

  const dispatch = jest.fn();

  function createComponent(notifiers?: {[K in keyof AppNotificationContextProps]: AppNotificationContextProps[K]}) {
    const props: AppNotificationContextProps = {
      notifySuccess: jest.fn(),
      notifyInfo: jest.fn(),
      notifyWarning: jest.fn(),
      notifyError: jest.fn(),
      ...notifiers
    };

    return (
      <AppNotificationProviderWithProps {...{...props}}>
        <AWSForm {...{activeProject, dispatch}} />
      </AppNotificationProviderWithProps>
    )
  }

  let fetchPricing: Promise<AWSInstanceChoiceOption[]>;
  let fetchRegions: Promise<AWSRegionList>;

  beforeEach(() => {
    jest.resetAllMocks();

    fetchPricing = Promise.resolve([
      new AWSInstanceChoiceOption({
        instanceType: 'm3a.small', numInstances: 1, maxThreadsByInstance: 500, hourlyCostByInstance: 0.092
      })
    ]);

    jest.spyOn(AWSEC2PricingService.prototype, 'list').mockReturnValue(fetchPricing);
  });

  beforeEach(() => {
    fetchRegions = Promise.resolve<AWSRegionList>({
      regions: [
        {
          code: 'North America',
          title: 'North America',
          regions: [
            { code: 'us-east-1', title: 'US East (Northern Virginia)' }
          ]
        }
      ],

      defaultRegion: { code: 'us-east-1', title: 'US East (Northern Virginia) ' }
    });

    jest.spyOn(AWSRegionService.prototype, 'list').mockReturnValue(fetchRegions);
  });

  it('should show form fields', async () => {
    const utils = render(createComponent());
    await fetchPricing;
    await utils.findByTestId('AWS Access Key');
    await utils.findByTestId('AWS Secret Key');
    await utils.findByTestId('VPC Subnet');
    await utils.findByTestId('Max. Users / Instance');
  });

  it('should show control for instance specifications', async () => {
    const component = mount(createComponent());
    await fetchRegions;
    await fetchPricing;
    component.update();
    expect(component).toContainExactlyOneMatchingElement('AWSInstanceChoice');
  });

  it('should show estimated cost based on defaults', async () => {
    const {findByText} = render(createComponent());
    await fetchRegions;
    await fetchPricing;
    const message = await findByText(/Hourly Cluster Cost/i);
    expect(message).toBeDefined();
  });

  it('should show control for AWS region', () => {
    const component = mount(createComponent());
    expect(component).toContainExactlyOneMatchingElement('AWSRegionChoice');
  });

  it('should validate cluster inputs', async () => {
    const {findByText, findByTestId, findAllByText} = render(createComponent());
    await fetchRegions;
    await fetchPricing;
    await findByText(/Hourly Cluster Cost/i);
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
    const {findByTestId, findByText} = render(createComponent());
    await fetchRegions;
    await fetchPricing;
    await findByText(/Hourly Cluster Cost/i);
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

  it('should update number of instances', async () => {
    const {findByTestId, debug} = render(createComponent());
    await fetchRegions;
    await fetchPricing;

    const maxPlannedUsers = await findByTestId('MaxPlannedUsers');
    fireEvent.change(maxPlannedUsers, {target: {value: '400'}});

    const maxThreadsByInst = await findByTestId('Max. Users / Instance');
    fireEvent.change(maxThreadsByInst, {target: {value: '80'}});

    const numInstances = await findByTestId('# Instances');
    expect(numInstances.textContent).toEqual('5');

    const hourlyCost = await findByTestId('Hourly Cluster Cost');
    expect(hourlyCost.textContent).toMatch(/0.46/);
  });

  it('should not set number of instances below 1', async () => {
    const {findByTestId} = render(createComponent());
    await fetchRegions;
    await fetchPricing;

    const maxPlannedUsers = await findByTestId('MaxPlannedUsers');
    fireEvent.change(maxPlannedUsers, {target: {value: '5000'}});

    const maxThreadsByInst = await findByTestId('Max. Users / Instance');
    fireEvent.change(maxThreadsByInst, {target: {value: '10000'}});

    const numInstances = await findByTestId('# Instances');
    expect(numInstances.textContent).toEqual('1');
  });

  it('should optionally submit baseAMI', async () => {
    const savedCluster: AmazonCluster = {
      id: 23,
      code: 'singing-penguin-23',
      title: '',
      type: 'AWS',
      accessKey: 'A',
      secretKey: 'S',
      region: 'sa-south-1',
      instanceType: 'm3a.small',
      maxThreadsByInstance: 500,
      baseAMI: 'ami-123'
    };

    const clusterSpy = jest.spyOn(ClusterService.prototype, 'create').mockResolvedValueOnce(savedCluster);
    const {findByRole, findByPlaceholderText, findByText, findByTestId} = render(createComponent());
    await fetchRegions;
    await fetchPricing;

    const editRegion = await findByRole('EditRegion');
    act(() => {
      fireEvent.click(editRegion);
    });

    const otherOption = await findByRole('OtherOption');
    act(() => {
      fireEvent.click(otherOption);
    })

    const region = await findByPlaceholderText('af-south-2');
    act(() => {
      fireEvent.change(region, {target: {value: 'af-south-1'}});
    });

    const ami = await findByPlaceholderText('ami-03ba3948f6c37a4b0');
    act(() => {
      fireEvent.change(ami, {target: {value: 'ami-123'}});
    });

    const submit = await findByText('Update');
    act(() => {
      fireEvent.click(submit);
    });

    await wait();
    const accessKey = await findByTestId('AWS Access Key');
    const secretKey = await findByTestId('AWS Secret Key');
    fireEvent.change(accessKey, {target: {value: savedCluster.accessKey}});
    fireEvent.change(secretKey, {target: {value: savedCluster.secretKey}});
    const save = await findByText(/save/i);
    fireEvent.click(save);
    await wait();

    expect(clusterSpy).toHaveBeenCalled();
    const args = clusterSpy.mock.calls[0][1] as AmazonCluster;
    expect(args.region).toEqual('af-south-1');
    expect(args.baseAMI).toBeDefined();
  });
});
