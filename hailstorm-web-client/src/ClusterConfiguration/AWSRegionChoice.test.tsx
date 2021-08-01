import React from 'react';
import { render, mount } from 'enzyme';
import { fireEvent, render as renderComponent, RenderResult, wait } from '@testing-library/react';
import { AWSRegionChoice } from './AWSRegionChoice';
import { AWSRegionList, AWSRegionType } from './domain';
import { act } from 'react-dom/test-utils';

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

  it('should show "Other" option on Edit', async () => {
    const component = mount(
      <AWSRegionChoice
        onAWSRegionChange={jest.fn()}
        {...{fetchRegions}}
      />
    );

    await regionsData;
    component.update();
    component.find('a[role="EditRegion"]').simulate('click');
    expect(component).toContainMatchingElement('*[role="OtherOption"]');
  });

  it('should not show "Other" option when a sub-region is selected', async () => {
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
    expect(component).not.toContainMatchingElement('*[role="OtherOption"]');
  });

  describe('when "Other" option is selected', () => {
    const onAWSRegionChange = jest.fn();
    let renderQueries: RenderResult;

    beforeEach(async () => {
      onAWSRegionChange.mockReset();
      renderQueries = renderComponent(
        <AWSRegionChoice
          {...{fetchRegions, onAWSRegionChange}}
        />
      );

      await regionsData;
      const {findByRole} = renderQueries;
      const editRegion = await findByRole('EditRegion');
      act(() => {
        fireEvent.click(editRegion);
      });

      const otherOption = await findByRole('OtherOption');
      act(() => {
        fireEvent.click(otherOption);
      })
    });

    it('should show fields for AWS region and base AMI', async () => {
      const {queryByPlaceholderText} = renderQueries;
      expect(queryByPlaceholderText('af-south-2')).toBeDefined();
      expect(queryByPlaceholderText('ami-03ba3948f6c37a4b0')).toBeDefined();
    });

    describe('when "Other" option is submitted', () => {
      beforeEach(async () => {
        const {findByPlaceholderText} = renderQueries;

        const region = await findByPlaceholderText('af-south-2');
        act(() => {
          fireEvent.change(region, {target: {value: 'af-south-1'}});
        });

        const ami = await findByPlaceholderText('ami-03ba3948f6c37a4b0');
        act(() => {
          fireEvent.change(ami, {target: {value: 'ami-123'}});
        });
      });

      it('should accept the inputs', async () => {
        const {findByText, queryByDisplayValue} = renderQueries;
        const submit = await findByText('Update');
        act(() => {
          fireEvent.click(submit);
        });

        await wait();
        expect(onAWSRegionChange).toHaveBeenCalledTimes(2);
        expect(queryByDisplayValue('ami-123')).not.toBeNull();
      });

      it('should remove base AMI if a pre-existing region is selected', async () => {
        const {findByText, findByRole, findAllByRole, findByDisplayValue, queryByDisplayValue} = renderQueries;
        const submit = await findByText('Update');
        act(() => {
          fireEvent.click(submit);
        });

        const editRegion = await findByRole('EditRegion');
        act(() => {
          fireEvent.click(editRegion);
        });

        const northAmerica = await findByRole('AWSRegionOption');
        act(() => {
          fireEvent.click(northAmerica);
        });

        const regions = await findAllByRole('AWSRegionOption');
        act(() => {
          fireEvent.click(regions[0]);
        });

        await findByDisplayValue('Ohio, US East');
        expect(queryByDisplayValue('ami-123')).toBeNull();
      });
    });
  });
});
