import React from 'react';
import { mount } from 'enzyme';
import { JtlDownloadModal } from './JtlDownloadModal';
import { act } from '@testing-library/react';

describe('<JtlDownloadModal />', () => {
  const setActive = jest.fn();

  it('should disable close button', () => {
    const component = mount(
      <JtlDownloadModal
        isActive={true}
        setActive={setActive}
        contentActive={true}
      />
    );

    expect(component.find('button')).toBeDisabled();
  });

  it('should enable/disable close button as checkbox is checked/unchecked', () => {
    const component = mount(
      <JtlDownloadModal
        isActive={true}
        setActive={setActive}
        contentActive={true}
      />
    );

    expect(component.find('button')).toBeDisabled();
    act(() => {
      component.find('input[type="checkbox"]').simulate('change');
    });
    component.update();
    expect(component.find('button')).not.toBeDisabled();
    act(() => {
      component.find('input[type="checkbox"]').simulate('change');
    });
    component.update();
    expect(component.find('button')).toBeDisabled();
  });

  it('should inactivate modal on close', () => {
    const component = mount(
      <JtlDownloadModal
        isActive={true}
        setActive={setActive}
        contentActive={true}
      />
    );

    act(() => {
      component.find('input[type="checkbox"]').simulate('change');
    });

    component.update();
    act(() => {
      component.find('button').simulate('click');
    });

    expect(setActive).toBeCalledWith(false);
  });
});
