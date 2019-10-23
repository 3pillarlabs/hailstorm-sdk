import React from 'react';
import { render, mount } from 'enzyme';
import { AWSInstanceChoice } from './AWSInstanceChoice';
import { AWSInstanceChoiceOption } from './domain';
import { render as renderComponent, fireEvent } from '@testing-library/react';

jest.mock('./NonLinearSlider', () => ({
  __esModule: true,
  NonLinearSlider: () => (
    <div id="NonLinearSlider"></div>
  )
}));

describe('<AWSInstanceChoice />', () => {
  let fetchPricing: Promise<AWSInstanceChoiceOption[]>;

  beforeEach(() => {
    jest.resetAllMocks();
  });

  beforeEach(() => {
    fetchPricing = Promise.resolve([
      new AWSInstanceChoiceOption({
        instanceType: 'm3a.small', numInstances: 1, maxThreadsByInstance: 500, hourlyCostByInstance: 0.092
      })
    ]);
  });

  it('should render without crashing', () => {
    render(<AWSInstanceChoice onChange={jest.fn()} fetchPricing={jest.fn()} regionCode="us-east-1" />);
  });

  it('should render a component to select max number of users', async () => {
    const component = mount(<AWSInstanceChoice onChange={jest.fn()} fetchPricing={() => fetchPricing} regionCode="us-east-1" />);
    await fetchPricing;
    component.update();
    expect(component).toContainExactlyOneMatchingElement('NonLinearSlider');
  });

  it('should show default values', async () => {
    const component = mount(<AWSInstanceChoice onChange={jest.fn()} fetchPricing={() => fetchPricing} regionCode="us-east-1" />);
    await fetchPricing;
    component.update();
    expect(component.find('NonLinearSlider')).toHaveProp('initialValue');
  });

  it('should recompute the choice when the slider is changed', async () => {
    const calculator = await import('./AWSInstanceCalculator');
    const computeSpy = jest.spyOn(calculator, 'computeChoice').mockReturnValue({
      instanceType: 'm5.large',
      numInstances: 1,
      hourlyCostByInstance: 0.192,
      maxThreadsByInstance: 1000,
      hourlyCostByCluster: jest.fn().mockReturnValue(8.34567)
    });

    const component = mount(<AWSInstanceChoice onChange={jest.fn()} fetchPricing={() => fetchPricing} regionCode="us-east-1" />);
    await fetchPricing;
    component.update();
    const onChange = component.find('NonLinearSlider').prop('onChange') as unknown as (value: number) => void;
    onChange(100);
    expect(computeSpy).toHaveBeenCalled();
  });

  it('should switch to advanced mode', async () => {
    const {findByText, findByTestId} = renderComponent(
      <AWSInstanceChoice onChange={jest.fn()} fetchPricing={() => fetchPricing} regionCode="us-east-1" />
    );

    await fetchPricing;
    const switchLink = await findByText(/advanced mode/i);
    fireEvent.click(switchLink);
    await findByText(/quick mode/i);
    await findByTestId('AWS Instance Type');
    await findByTestId('Max. Users / Instance');
  });

  describe('when in advanced mode', () => {
    it('should edit AWS instance type and max users by instance', async () => {
      const {findByText, findByTestId, findByDisplayValue} = renderComponent(
        <AWSInstanceChoice onChange={jest.fn()} fetchPricing={() => fetchPricing} regionCode="us-east-1" />
      );

      await fetchPricing;
      const switchLink = await findByText(/advanced mode/i);
      fireEvent.click(switchLink);
      const awsInstanceType = await findByTestId('AWS Instance Type');
      const maxThreadsPerInstance = await findByTestId('Max. Users / Instance');
      fireEvent.change(awsInstanceType, {target: {value: 't2.small'}});
      fireEvent.change(maxThreadsPerInstance, {target: {value: '25'}});
      await findByDisplayValue('t2.small');
      await findByDisplayValue('25');
      expect(awsInstanceType.getAttribute('value')).toEqual('t2.small');
      expect(maxThreadsPerInstance.getAttribute('value')).toEqual('25');
    });

    it('should restore defaults when switched backed to quick mode', async () => {
      const calculator = await import('./AWSInstanceCalculator');
      jest.spyOn(calculator, 'computeChoice').mockReturnValue({
        instanceType: 'm5a.large',
        numInstances: 1,
        hourlyCostByInstance: 0.192,
        maxThreadsByInstance: 500,
        hourlyCostByCluster: jest.fn().mockReturnValue(8.34567)
      });

      const {findByText, findByTestId} = renderComponent(
        <AWSInstanceChoice onChange={jest.fn()} fetchPricing={() => fetchPricing} regionCode="us-east-1" />
      );

      await fetchPricing;
      let switchLink = await findByText(/advanced mode/i);
      fireEvent.click(switchLink);
      let awsInstanceType = await findByTestId('AWS Instance Type');
      let maxThreadsPerInstance = await findByTestId('Max. Users / Instance');
      fireEvent.change(awsInstanceType, {target: {value: 't2.small'}});
      fireEvent.change(maxThreadsPerInstance, {target: {value: '25'}});

      switchLink = await findByText(/quick mode/i);
      fireEvent.click(switchLink);
      awsInstanceType = await findByTestId('AWS Instance Type');
      maxThreadsPerInstance = await findByTestId('Max. Users / Instance');
      expect(awsInstanceType.textContent).toMatch(/m5a\.large/);
      expect(maxThreadsPerInstance.textContent).toMatch(/500/);
    });

    it('should not report hourly cost', async () => {
      const setHourlyCostByCluster = jest.fn();
      const {findByText} = renderComponent(
        <AWSInstanceChoice
          onChange={jest.fn()}
          fetchPricing={() => fetchPricing}
          regionCode="us-east-1"
          {...{setHourlyCostByCluster}}
        />
      );

      await fetchPricing;
      const switchLink = await findByText(/advanced mode/i);
      fireEvent.click(switchLink);
      expect(setHourlyCostByCluster).toBeCalledWith(undefined);
    });
  });

  it('should update pricing as region is changed', async () => {
    const calculator = await import('./AWSInstanceCalculator');
    const computeSpy = jest.spyOn(calculator, 'computeChoice').mockReturnValue({
      instanceType: 'm5a.large',
      numInstances: 1,
      hourlyCostByInstance: 0.192,
      maxThreadsByInstance: 500,
      hourlyCostByCluster: jest.fn().mockReturnValue(8.34567)
    });

    const component = mount(<AWSInstanceChoice onChange={jest.fn()} fetchPricing={() => fetchPricing} regionCode="us-east-1" />);
    await fetchPricing;
    component.update();
    const onChange = component.find('NonLinearSlider').prop('onChange') as unknown as (value: number) => void;
    console.debug(onChange);
    onChange(1000);
    component.update();
    expect(computeSpy).toBeCalledTimes(2);
    let sliderValue = computeSpy.mock.calls[1][0];
    expect(sliderValue).toEqual(1000);

    component.setProps({regionCode: 'us-west-1'});
    await fetchPricing;
    component.update();
    expect(computeSpy).toBeCalledTimes(3);
    sliderValue = computeSpy.mock.calls[2][0];
    expect(sliderValue).toEqual(1000);
  });
});
