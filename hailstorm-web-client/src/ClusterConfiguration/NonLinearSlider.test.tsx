import React from 'react';
import { NonLinearSlider } from './NonLinearSlider';
import { render, mount } from 'enzyme';

describe('<NonLinearSlider />', () => {
  it('should render without crashing', () => {
    render(<NonLinearSlider onChange={jest.fn()} />);
  });

  it('should display the slider value', () => {
    const component = mount(<NonLinearSlider initialValue={100} onChange={jest.fn()} />);
    expect(component.text()).toMatch(/100/);
  });

  it('should trigger onChange when the value is changed', () => {
    const onChange = jest.fn();
    const component = mount(<NonLinearSlider initialValue={50} {...{onChange}} />);
    component.find('input').simulate('change', {target: {value: 100}});
    expect(onChange).toHaveBeenCalledWith(100);
  });

  it('should cap value at maximum', () => {
    const onChange = jest.fn();
    const component = mount(<NonLinearSlider initialValue={50} maximum={1000} {...{onChange}} />);
    component.find('input').simulate('change', {target: {value: 10000}});
    expect(onChange).toHaveBeenCalledWith(1000);
  });

  it('should limit value at minimum', () => {
    const onChange = jest.fn();
    const component = mount(<NonLinearSlider initialValue={50} minimum={50} maximum={1000} {...{onChange}} />);
    component.find('input').simulate('blur', {target: {value: 10}});
    expect(component.find('input').prop('value')).toEqual(50);
    expect(onChange).not.toHaveBeenCalled();
  });
});
