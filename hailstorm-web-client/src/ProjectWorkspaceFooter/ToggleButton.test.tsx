import React from 'react';
import { shallow, mount } from 'enzyme';
import { ToggleButton } from './ToggleButton';

describe('<ToggleButton />', () => {

  it('should render without crashing', () => {
    shallow(<ToggleButton isPressed={true} setIsPressed={jest.fn()} />);
  });

  it('should invoke callback on button press', () => {
    const clickHandler = jest.fn();
    const component = mount(<ToggleButton isPressed={false} setIsPressed={clickHandler} />);
    component.find('button').simulate('click');
    expect(clickHandler).toBeCalledWith(true);
  });
});
