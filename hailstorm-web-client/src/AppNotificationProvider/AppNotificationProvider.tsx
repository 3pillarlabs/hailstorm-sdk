import React, { useState } from 'react';
import { AppNotificationContext, AppNotificationContextProps, AppNotificationSystem } from '../app-notifications';
import { NotificationCenter } from '../NotificationCenter';

export function AppNotificationProvider({children}: React.PropsWithChildren<{}>) {
  const [notificationSystem] = useState<AppNotificationSystem>(new AppNotificationSystem());
  const notifiers = notificationSystem.createNotifiers();

  return (
    <>
      <NotificationCenter notificationChannel={notificationSystem.createChannel()} />
      <AppNotificationProviderWithProps {...{...notifiers}}>
        {children}
      </AppNotificationProviderWithProps>
    </>
  )
}

export function AppNotificationProviderWithProps(props: React.PropsWithChildren<AppNotificationContextProps>) {
  const {notifyError, notifyInfo, notifySuccess, notifyWarning} = props;

  return (
    <AppNotificationContext.Provider value={{notifyError, notifyInfo, notifySuccess, notifyWarning}}>
    {props.children}
    </AppNotificationContext.Provider>
  )
}
