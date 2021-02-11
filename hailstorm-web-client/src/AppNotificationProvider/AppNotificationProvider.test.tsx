import { render } from '@testing-library/react';
import { mount } from 'enzyme';
import React from 'react';
import { useNotifications } from '../app-notifications';
import { AppNotificationProvider } from './AppNotificationProvider';

jest.mock(`../NotificationCenter`, () => ({
  __esModule: true,
  NotificationCenter: () => (
    <div id="NotificationCenter"></div>
  )
}));

describe('<AppNotificationProvider />', () => {

  it('should not crash', () => {
    render(<AppNotificationProvider></AppNotificationProvider>);
  });


  it('should provide the notification context', () => {
    const AppComponent = () => {
      const notifiers = useNotifications();

      return (
        <div id="AppComponent">
          {notifiers.notifySuccess('') === undefined && (<span id="notifySuccess">OK</span>)}
          {notifiers.notifyError('') === undefined && (<span id="notifyError">OK</span>)}
          {notifiers.notifyInfo('') === undefined && (<span id="notifyInfo">OK</span>)}
          {notifiers.notifyWarning('') === undefined && (<span id="notifyWarning">OK</span>)}
        </div>
      )
    };

    const component = mount(
      <AppNotificationProvider>
        <AppComponent />
      </AppNotificationProvider>
    );

    expect(component.find('#notifySuccess')).toExist();
    expect(component.find('#notifyError')).toExist();
    expect(component.find('#notifyInfo')).toExist();
    expect(component.find('#notifyWarning')).toExist();
  });
});
