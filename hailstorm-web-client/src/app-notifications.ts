import { createContext, useContext } from 'react';
import { Subject, Subscription } from 'rxjs';

export interface AppNotificationContextProps {
  notifySuccess: (message: string) => void;
  notifyError: (message: string, reason?: any) => void;
  notifyWarning: (message: string) => void;
  notifyInfo: (message: string) => void;
}

export const AppNotificationContext = createContext<AppNotificationContextProps>({
  notifySuccess: () => { throw new Error('#notifySuccess is not implemented') },
  notifyError: () => { throw new Error('#notifyError is not implemented') },
  notifyInfo: () => { throw new Error('#notifyInfo is not implemented') },
  notifyWarning: () => { throw new Error('#notifyWarning is not implemented') }
});

export function useNotifications() {
  return useContext(AppNotificationContext);
}

export type NotificationType = 'success' | 'info' | 'warn' | 'error';

export interface NotificationLike {
  type: NotificationType;
  message: string;
  errorReason: string | undefined;
}

export interface NotificationRecord extends NotificationLike {
  id: number;
  timestamp: number;
}

export class Notification implements NotificationRecord {

  private _id: number;
  private _timestamp: number;
  private _errorReason: string | undefined;

  constructor(
    private _message: string,
    private _type: NotificationType,
    __errorReason?: Error | string | undefined
  ) {
    this._timestamp = new Date().valueOf();
    this._id = this._timestamp * Math.random();
    if (__errorReason) {
      this._errorReason = __errorReason instanceof Error ? __errorReason.message : __errorReason;
    }
  }

  public get type(): NotificationType {
    return this._type;
  }

  public get message(): string {
    return this._message;
  }

  public get errorReason(): string | undefined {
    return this._errorReason;
  }

  public get id(): number {
    return this._id;
  }

  public get timestamp(): number {
    return this._timestamp;
  }

  isError(): boolean {
    return this.type === 'error';
  }

  isWarning(): boolean {
    return this.type === 'warn';
  }
}

export class SuccessNotification extends Notification {
  constructor(message: string) {
    super(message, 'success');
  }
}

export class InfoNotification extends Notification {
  constructor(message: string) {
    super(message, 'info');
  }
}

export class WarnNotification extends Notification {
  constructor(message: string) {
    super(message, 'warn');
  }
}

export class ErrorNotification extends Notification {
  constructor(message: string, errorReason?: Error | string) {
    super(message, 'error', errorReason);
  }
}

export class NotificationChannel {

  private subscription: Subscription | undefined;

  constructor(private subject: Subject<Notification>) {}

  subscribe(messageHandler: (notification: Notification) => void) {
    this.subscription = this.subject.subscribe((message) => messageHandler(message));
  }

  unsubscribe() {
    this.subscription && this.subscription.unsubscribe();
  }
}

export class AppNotificationSystem {

  private subject: Subject<Notification>;

  constructor() {
    this.subject = new Subject<Notification>();
  }

  createNotifiers(): AppNotificationContextProps {
    return {
      notifySuccess: (message) => this.subject.next(new SuccessNotification(message)),
      notifyInfo: (message) => this.subject.next(new InfoNotification(message)),
      notifyWarning: (message) => this.subject.next(new WarnNotification(message)),
      notifyError: (message, reason) => this.subject.next(new ErrorNotification(message, reason))
    }
  }

  createChannel(): NotificationChannel {
    return new NotificationChannel(this.subject);
  }
}
