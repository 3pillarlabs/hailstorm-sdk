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

  test.todo('should show test plans in list of test plans');

  test.todo('should show data files in list of test plans');
});
