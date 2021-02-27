import { fireEvent, render, wait } from '@testing-library/react';
import React from 'react';
import { act } from 'react-dom/test-utils';
import { interval, Subject, Subscription } from 'rxjs';
import { take } from 'rxjs/operators';
import { NotificationChannel, Notification, NotificationType, ErrorNotification, SuccessNotification, InfoNotification, WarnNotification } from '../app-notifications';
import { NotificationCenter } from './NotificationCenter';

describe('<NotificationCenter />', () => {
  const subject = new Subject<Notification>();
  const notificationChannel = new NotificationChannel(subject);

  function component(args?: {refreshInterval?: number, displayDuration?: number, displayLimit?: number}) {
    return (
      <NotificationCenter {...{notificationChannel, ...args}} />
    )
  }

  it('should render without crashing', () => {
    render(component());
  });

  const notificationTypes: NotificationType[] = ['success', 'info', 'warn', 'error'];
  notificationTypes.forEach((type) => {
    it(`should show a ${type} message`, async () => {
      const {findByText, debug} = render(component());
      act(() => {
        subject.next(new Notification(`test ${type}`, type));
      });

      await findByText(new RegExp(`test ${type}`));
    });
  });

  it('should show error reason', async () => {
    const {findByText} = render(component());
    act(() => {
      subject.next(new ErrorNotification(`test error`, new Error('formal error')));
      subject.next(new ErrorNotification(`test error`, 'plain reason'));
    });

    await findByText('formal error');
    await findByText('plain reason');
  });

  it('should show multiple kinds of messages', async () => {
    const {findByText} = render(component());
    act(() => {
      subject.next(new SuccessNotification(`test success`));
      subject.next(new InfoNotification(`test info`));
    });

    await findByText(/test success/);
    await findByText(/test info/);
  });

  it('should remove old messages after a time interval', async (done) => {
    const {findByText, queryAllByText} = render(component({refreshInterval: 10, displayDuration: 30}));
    act(() => {
      subject.next(new SuccessNotification(`test success`));
      subject.next(new InfoNotification(`test info`));
    });

    await findByText(/test success/);
    await findByText(/test info/);

    setTimeout(() => {
      done();
      const messages = queryAllByText(/test/);
      expect(messages).toHaveLength(0);
    }, 40);
  });

  it('should not remove error messages automatically', async (done) => {
    const {findByText, queryAllByText} = render(component({refreshInterval: 10, displayDuration: 20}));
    act(() => {
      subject.next(new ErrorNotification(`test error`));
    });

    await findByText(/test error/);

    setTimeout(() => {
      done();
      const messages = queryAllByText(/test error/);
      expect(messages).toHaveLength(1);
    }, 30);
  });

  it('should throttle the message flow', async () => {
    const {findAllByText, queryByText} = render(
      component({displayLimit: 3, displayDuration: 20, refreshInterval: 10})
    );

    let ticker: Subscription | undefined;
    act(() => {
      ticker = interval(1).pipe(take(23)).subscribe({
        next: (tick) => {
          subject.next(new InfoNotification(`test ${tick}`));
        }
      });
    });

    const messages = await findAllByText(/test/);
    if (ticker !== undefined) {
      ticker.unsubscribe();
    }

    expect(messages).toHaveLength(3);

    await wait(() => {
      expect(queryByText(`test 3`)).toBeDefined();
    }, {timeout: 100, interval: 25});
  });

  it('should not throttle a warning or error', (done) => {
    const componentProps = { displayLimit: 3, displayDuration: 180, refreshInterval: 10 };
    const {queryAllByText} = render(
      component(componentProps)
    );

    let ticker: Subscription | undefined;
    act(() => {
      ticker = interval(1).pipe(take(23)).subscribe({
        next: (tick) => {
          subject.next(new ErrorNotification(`test ${tick}`));
        }
      });
    });

    setTimeout(() => {
      done();
      if (ticker !== undefined) {
        ticker.unsubscribe();
      }
      const messages = queryAllByText(/test/);
      expect(messages.length).toBeGreaterThan(componentProps.displayLimit);
    }, 300);
  });

  notificationTypes.filter((type) => ['error', 'warn'].includes(type)).forEach((type) => {
    it(`should let the user close ${type} messages`, async () => {
      const {findByText, queryByText} = render(component());
      act(() => {
        subject.next(type === 'error' ? new ErrorNotification(`test error`) : new WarnNotification(`test warning`));
      });

      await findByText(/test/);

      const closeButton = await findByText('Close');
      fireEvent.click(closeButton);

      const message = queryByText(/test/);
      expect(message).toBeNull();
    });
  });

  it('should let the user dismiss a message', async () => {
    const {findByText, findByTitle, queryByText} = render(component());
    act(() => {
      subject.next(new SuccessNotification(`test success`));
    });

    await findByText(/test success/);

    const closeButton = await findByTitle('Close');
    fireEvent.click(closeButton);

    const message = queryByText(/test success/);
    expect(message).toBeNull();
  });
});
