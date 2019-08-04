import React from 'react';
import { TopNav } from './TopNav';
import { shallow } from 'enzyme';

describe('<TopNav />', () => {
  it('should render without crashing', () => {
    shallow(<TopNav/>);
  });

  it('should toggle burger menu', () => {
    const component = shallow(<TopNav />);
    expect(component).toContainExactlyOneMatchingElement('a.navbar-burger');
    expect(component.find('.navbar-menu')).not.toHaveClassName('is-active');
    component.find('a.navbar-burger').simulate('click', { currentTarget: { classList: { toggle: jest.fn() } } });
    expect(component.find('.navbar-menu')).toHaveClassName('is-active');
  });
});
