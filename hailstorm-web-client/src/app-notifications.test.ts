import { AppNotificationSystem, Notification, NotificationType } from "./app-notifications";

describe('app-notifications', () => {
  describe('AppNotificationSystem', () => {
    const notificationSystem = new AppNotificationSystem();
    const {notifySuccess, notifyInfo, notifyWarning, notifyError} = notificationSystem.createNotifiers();
    const typeFnMap: {[msgType in NotificationType]: (...args: any[]) => void} = {
      success: notifySuccess,
      info: notifyInfo,
      warn: notifyWarning,
      error: notifyError
    };

    Object.entries(typeFnMap).forEach(([msgType, notifyFn]) => {
      it(`should receive a ${msgType} message`, () => {
        const received: Notification[] = [];
        const channel = notificationSystem.createChannel();
        channel.subscribe((notification) => {
          received.push(notification);
        });

        notifyFn('test message');
        expect(received).toHaveLength(1);
        expect(received[0].type).toBe(msgType);
        channel.unsubscribe();
      });
    });
  })
});
