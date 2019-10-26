import React from 'react';
import { render, mount } from 'enzyme';
import { AWSRegionChoice } from './AWSRegionChoice';
import { AWSRegionList, AWSRegionType } from './domain';
import { wait, waitForDomChange } from '@testing-library/dom';
import { validate } from '@babel/types';

describe('<AWSRegionChoice />', () => {
  const region: AWSRegionType = { code: 'us-east-1', title: 'Ohio, US East' };
  let regionsData: Promise<AWSRegionList>;
  const fetchRegions = jest.fn();

  beforeEach(() => jest.resetAllMocks());

  beforeEach(() => {
    regionsData = Promise.resolve({
      regions: [
        {
          code: 'North America',
          title: 'North America',
          regions: [
            region,
            { code: 'us-west-1', title: 'US West (Northern California)' }
          ]
        }
      ],

      defaultRegion: region
    });

    fetchRegions.mockReturnValue(regionsData);
  });

  it('should render without crashing', () => {
    render(<AWSRegionChoice onAWSRegionChange={jest.fn()} fetchRegions={jest.fn()} />);
  });

  it('should show a default region', async () => {
    const component = mount(
      <AWSRegionChoice
        onAWSRegionChange={jest.fn()}
        {...{fetchRegions}}
      />
    );

    await regionsData;
    component.update();
    expect(component.find('input').prop('value')).toMatch(new RegExp(region.title));
  });

  it('should show the top level regions on Edit', async () => {
    const component = mount(
      <AWSRegionChoice
        onAWSRegionChange={jest.fn()}
        {...{fetchRegions}}
      />
    );

    await regionsData;
    component.update();
    component.find('a[role="EditRegion"]').simulate('click');
    expect(component).toContainMatchingElement('*[role="AWSRegionOption"]')
  });

  it('should show second level regions', async () => {
    const component = mount(
      <AWSRegionChoice
        onAWSRegionChange={jest.fn()}
        {...{fetchRegions}}
      />
    );

    await regionsData;
    component.update();
    component.find('a[role="EditRegion"]').simulate('click');
    component.find('*[role="AWSRegionOption"]').simulate('click');
    expect(component.find('*[role="AWSRegionOption"]').findWhere((wrapper) => wrapper.text() === 'Ohio, US East').at(0)).toExist();
  });

  it('should select a sub region based on user choice', async () => {
    const component = mount(
      <AWSRegionChoice
        onAWSRegionChange={jest.fn()}
        {...{fetchRegions}}
      />
    );

    await regionsData;
    component.update();
    component.find('a[role="EditRegion"]').simulate('click');
    component.find('*[role="AWSRegionOption"]').simulate('click');
    component.find('*[role="AWSRegionOption"]').at(1).simulate('click');
    expect(component.find('input').prop('value')).toMatch(/us west/i);
  });

  it('should cancel to original state', async () => {
    const component = mount(
      <AWSRegionChoice
        onAWSRegionChange={jest.fn()}
        {...{fetchRegions}}
      />
    );

    await regionsData;
    component.update();
    component.find('a[role="EditRegion"]').simulate('click');
    component.find('a.is-link').simulate('click');
    expect(component.find('input').prop('value')).toMatch(new RegExp(region.title));

    component.find('a[role="EditRegion"]').simulate('click');
    component.find('*[role="AWSRegionOption"]').simulate('click');
    component.find('a.is-link').simulate('click');
    expect(component.find('input').prop('value')).toMatch(new RegExp(region.title));
  });

  it('should be possible to disable the control', async () => {
    const component = mount(
      <AWSRegionChoice
        onAWSRegionChange={jest.fn()}
        {...{fetchRegions}}
        disabled={true}
      />
    );

    await regionsData;
    component.update();
    expect(component.find('span[role="EditRegion"]')).toExist();
  });
});
