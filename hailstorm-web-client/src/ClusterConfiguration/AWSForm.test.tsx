import React from 'react';
import { AmazonCluster, Cluster, Project } from '../domain';
import { AWSForm } from './AWSForm';
import { AWSInstanceChoiceOption, AWSRegionList } from './domain';
import { AWSEC2PricingService } from '../services/AWSEC2PricingService';
import { fireEvent, render, wait } from '@testing-library/react';
import { AWSRegionService } from '../services/AWSRegionService';
import { mount } from 'enzyme';
import { ClusterService } from '../services/ClusterService';

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

  function createComponent() {
    return (
      <AWSForm
        {...{activeProject, dispatch}}
      />
    )
  }

  let fetchPricing: Promise<AWSInstanceChoiceOption[]>;
  let fetchRegions: Promise<AWSRegionList>;

  beforeEach(() => {
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
            { code: 'us-east-1', title: 'Ohio, US East' }
          ]
        }
      ],

      defaultRegion: { code: 'us-east-1', title: 'Ohio, US East' }
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
    const message = await findByText(/Cluster Cost/i);
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
    await findByText(/Cluster Cost/i);
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
    await findByText(/Cluster Cost/i);
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
