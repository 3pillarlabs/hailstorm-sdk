import React from 'react';
import { TopNav } from './TopNav';
import { shallow } from 'enzyme';

describe('<TopNav />', () => {
  it('should render without crashing', () => {
    shallow(<TopNav/>);
  });
});
