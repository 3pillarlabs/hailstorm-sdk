import React from 'react';
import { shallow } from 'enzyme';
import { JMeterPlanList } from './JMeterPlanList';

describe('<JMeterPlanList />', () => {
  it('should render without crashing', () => {
    shallow(<JMeterPlanList />)
  });
});
