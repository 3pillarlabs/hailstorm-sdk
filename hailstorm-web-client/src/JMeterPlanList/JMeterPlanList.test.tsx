import React from 'react';
import { shallow, mount } from 'enzyme';
import { JMeterPlanList } from './JMeterPlanList';

describe('<JMeterPlanList />', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    shallow(<JMeterPlanList jmeter={{files: []}} />)
  });

  it('should show test plans in list of test plans', () => {
    const component = mount(
      <JMeterPlanList jmeter={{files: [
        { name: 'a.jmx' },
        { name: 'b.jmx' }
      ]}} />
    );

    expect(component).toContainMatchingElements(2, 'i[role="JMeter Plan"]');
  });

  it('should show data files in list of test plans', () => {
    const component = mount(
      <JMeterPlanList jmeter={{files: [
        { name: 'a.jmx' },
        { name: 'a.csv', dataFile: true }
      ]}} />
    );

    expect(component).toContainMatchingElements(1, 'i[role="Data File"]');
  });

  it('should set a file as selected', () => {
    const handleSelect = jest.fn();
    const component = mount(
      <JMeterPlanList
        jmeter={{files: [
          { name: 'a.jmx' }
        ]}}
        onSelect={handleSelect}
      />
    );

    component.find('a').simulate('click');
    expect(handleSelect).toBeCalledWith({name: 'a.jmx'});
  });

  it('should highlight active file in file list', () => {
    const component = mount(
      <JMeterPlanList
        jmeter={{files: [
          {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])},
          {id: 99, name: 'a.csv', dataFile: true}
        ]}}
        onSelect={jest.fn()}
        activeFile={{id: 99, name: 'a.csv', dataFile: true}}
      />
    );

    const blocks = component.find('a').findWhere((wrapper) => wrapper.hasClass('panel-block'));
    expect(blocks.at(1).hasClass('is-active')).toBeTruthy();
  });

  it('should disable edit link', () => {
    const wrapper = shallow(<JMeterPlanList jmeter={{files: []}} disableEdit={true} showEdit={true} />);
    expect(wrapper.find('.button')).toBeDisabled();
  });
});
