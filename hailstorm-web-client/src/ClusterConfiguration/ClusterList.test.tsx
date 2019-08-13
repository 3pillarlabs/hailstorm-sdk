import React from 'react';
import { shallow } from 'enzyme';
import { ClusterList } from './ClusterList';

describe('<ClusterList />', () => {
  it('should render without crashing', () => {
    shallow(<ClusterList />);
  });
});
