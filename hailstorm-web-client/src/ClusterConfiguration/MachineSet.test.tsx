import React from 'react';
import { render, mount } from 'enzyme';
import { MachineSet } from './MachineSet';

describe('<MachineSet />', () => {
  it('should render without crashing', () => {
    render(
      <MachineSet
        name="machines"
        onChange={jest.fn()}
      />
    );
  });

  it('should show two fields initially', () => {
    const component = mount(
      <MachineSet
        name="machines"
        onChange={jest.fn()}
      />
    );

    expect(component).toContainMatchingElements(2, 'input[type="text"]');
  });

  it('should show another field when the last field has a value', () => {
    const component = mount(
      <MachineSet
        name="machines"
        onChange={jest.fn()}
      />
    );

    component.find('input[type="text"]').at(0).simulate('change', {target: {value: 'a'}});
    component.find('input[type="text"]').at(1).simulate('change', {target: {value: 'b'}});
    expect(component).toContainMatchingElements(3, 'input[type="text"]');
    component.find('input[type="text"]').at(2).simulate('change', {target: {value: 'c'}});
    expect(component).toContainMatchingElements(4, 'input[type="text"]');
    expect(component.find('input[type="text"]').at(3).prop('value')).toBeFalsy();
  });

  it('should remove extra field if last field value is empty', () => {
    const component = mount(
      <MachineSet
        name="machines"
        onChange={jest.fn()}
      />
    );

    component.find('input[type="text"]').at(0).simulate('change', {target: {value: 'a'}});
    component.find('input[type="text"]').at(1).simulate('change', {target: {value: 'b'}});
    component.find('input[type="text"]').at(1).simulate('change', {target: {value: ''}});
    expect(component).toContainMatchingElements(2, 'input[type="text"]');
  });

  it('should send back only fields with value', () => {
    const onChange = jest.fn();
    const component = mount(
      <MachineSet
        name="machines"
        {...{onChange}}
      />
    );

    component.find('input[type="text"]').at(0).simulate('change', {target: {value: 'a'}});
    expect(onChange).toBeCalledWith(['a']);
  });

  it('should show errors associated with machines', () => {
    const component = mount(
      <MachineSet
        name="machines"
        onChange={jest.fn()}
      />
    );

    component.find('input[type="text"]').at(0).simulate('change', {target: {value: 'a'}});
    component.setProps({machineErrors: { 'a': 'not reachable' }});
    expect(component).toContainMatchingElements(1, 'p.is-danger');
  });

  it('should disable fields', () => {
    const component = mount(
      <MachineSet
        name="machines"
        disabled={true}
        onChange={jest.fn()}
      />
    );

    expect(component.find('input[type="text"]').at(0)).toBeDisabled();
    expect(component.find('input[type="text"]').at(1)).toBeDisabled();
  });

  it('should always have two fields', () => {
    const component = mount(
      <MachineSet
        name="machines"
        onChange={jest.fn()}
      />
    );

    component.find('input[type="text"]').at(0).simulate('change', {target: {value: 'a'}});
    component.find('input[type="text"]').at(0).simulate('change', {target: {value: ''}});
    expect(component).toContainMatchingElements(2, 'input[type="text"]');
  });

  it('should break up values with whitespace into multiple fields', () => {
    const component = mount(
      <MachineSet
        name="machines"
        onChange={jest.fn()}
      />
    );

    component.find('input[type="text"]').at(0).simulate('change', {target: {value: 'a b c d e'}});
    expect(component).toContainMatchingElements(6, 'input[type="text"]');
  });
});
