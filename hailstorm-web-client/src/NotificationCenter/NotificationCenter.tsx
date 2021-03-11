import React, { useEffect, useState } from "react";
import { interval, queueScheduler } from "rxjs";
import { Notification, NotificationChannel, NotificationType } from "../app-notifications";
import styles from "./NotificationCenter.module.scss";

const DEFAULT_REFRESH_INTERVAL_MS = 2500;
const DEFAULT_DISPLAY_DUR_MS = 5000;
const DEFAULT_DISPLAY_LIMIT = 5;

interface Toast {
  notification: Notification;
  closeHandler: () => void;
}

export function NotificationCenter({
  notificationChannel,
  refreshInterval,
  displayDuration,
  displayLimit,
}: {
  notificationChannel: NotificationChannel;
  refreshInterval?: number;
  displayDuration?: number;
  displayLimit?: number;
}) {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const periodicBeat = interval(
    refreshInterval || DEFAULT_REFRESH_INTERVAL_MS,
    queueScheduler
  );

  const removeToast = (id: number) => {
    setNotifications((current) => current.filter((not) => not.id !== id));
  };

  useEffect(() => {
    console.debug("NotificationCenter#useEffect() 1");
    notificationChannel.subscribe((notification) => {
      setNotifications((currentNotifications) => [
        ...currentNotifications,
        notification,
      ]);
    });

    return () => {
      console.debug("NotificationCenter#useEffect() 1 unmount");
      notificationChannel.unsubscribe();
    };
  }, []);

  useEffect(() => {
    console.debug("NotificationCenter#useEffect() 2");
    const intervalSubscription = periodicBeat.subscribe({
      next: () => {
        const now = new Date().valueOf();
        setNotifications((currentNotifications) =>
          currentNotifications.filter(
            (notification) =>
              notification.isError() ||
              notification.isWarning() ||
              now - notification.timestamp <
                (displayDuration || DEFAULT_DISPLAY_DUR_MS)
          )
        );
      },
    });

    return () => {
      console.debug("NotificationCenter#useEffect() 2 unmount");
      intervalSubscription.unsubscribe();
    };
  }, []);

  const errorsAndWarnings = notifications.filter(
    (notification) => notification.isError() || notification.isWarning()
  );

  const otherMessages = notifications
    .filter(
      (notification) => !notification.isError() && !notification.isWarning()
    )
    .slice(0, displayLimit || DEFAULT_DISPLAY_LIMIT);

  const toasts: Toast[] = [...errorsAndWarnings, ...otherMessages].map(
    (notification) => ({
      notification,
      closeHandler: () => removeToast(notification.id),
    })
  );

  return (
    <div className={styles.container}>
      {toasts.map(showNotification)}
    </div>
  );
}

function showNotification({ notification, closeHandler }: Toast): JSX.Element {
  return (
    <NotificationToast
      key={notification.id}
      {...{ notification, closeHandler }}
    />
  );
}

function NotificationToast({ notification, closeHandler }: Toast) {
  const { type, message, errorReason } = notification;

  return (
    <div className={styles.item}>
      <div className={`notification is-${type} is-light`}>
        <button className="delete" title="Close" onClick={closeHandler}></button>
        <div className={styles.message}>
          <MessageIcon type={notification.type} /> {message.replace(/\.?$/, '.')}
        </div>
        {errorReason && (<ErrorDetails {...{errorReason}} />)}
        {(notification.isError() || notification.isWarning()) && (
        <div className={styles.actions}>
          <button className="button is-small" onClick={closeHandler}>Close</button>
        </div>)}
      </div>
    </div>
  );
}

function ErrorDetails({errorReason}: {errorReason: any}) {
  const [hideDetails, setHideDetails] = useState(true);

  return (
    <div className={styles.errorReason}>
      <div className={styles.toggleIcon} onClick={() => setHideDetails(!hideDetails)}>
        Details <span className="icon">
          {hideDetails ? (<i className="fas fa-angle-right"></i>) : (<i className="fas fa-angle-down"></i>)}
        </span>
      </div>
      <div className={hideDetails ? `is-hidden` : undefined}>
        {errorReason instanceof Error ? errorReason.message : errorReason.toString()}
      </div>
    </div>
  )
}

function MessageIcon({type}: {type: NotificationType}) {
  let iconClass: string;
  switch (type) {
    case 'success':
      iconClass = 'fas fa-check-circle';
      break;

    case 'info':
      iconClass = 'fas fa-info-circle';
      break;

    case 'warn':
      iconClass = 'fas fa-exclamation-circle';
      break;

    default:
      iconClass = 'fas fa-bomb';
      break;
  }

  return (
    <span className="icon">
      <i className={iconClass}></i>
    </span>
  )
}
