import React from 'react';
import { shallow, mount } from 'enzyme';
import { ClusterList } from './ClusterList';

describe('<ClusterList />', () => {
  it('should render without crashing', () => {
    shallow(<ClusterList />);
  });

  it('should show clusters list', () => {
    const component = mount(
      <ClusterList clusters={[
        {id: 1, type: 'AWS', title: 'AWS us-east-1', code: 'aws-1' }
      ]} />
    );

    expect(component).toContainMatchingElements(1, 'a.panel-block');
  });
});
