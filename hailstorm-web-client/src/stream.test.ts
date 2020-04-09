import { LogStream } from './stream';
import { Project, LogEvent } from './domain';
import { of, Observable } from 'rxjs';
import { RSocketClient } from 'rsocket-core';
import { wait } from '@testing-library/dom';

describe('stream', () => {
  const project: Project = { id: 1, code: 'a', title: 'A', running: true };

  it('should stream log events', (done) => {
    const capturedEvents: LogEvent[] = [];
    const sourceEvents: LogEvent[] = [
      { level: "DEBUG", priority: 0, timestamp: 1574916638429, message: "opening AWS connection..." },
      { level: "INFO", priority: 1, timestamp: 1574916838429, message: "Connected to VM" },
      { level: "WARN", priority: 2, timestamp: 1574918838429, message: "Could not find binary in default location" },
      { level: "ERROR", priority: 3, timestamp: 1574919838429, message: "Failed to connect to JMeter instance" },
    ];

    const mockEventSource: Observable<LogEvent> = of<LogEvent>(...sourceEvents);
    jest.spyOn(RSocketClient.prototype, 'close').mockImplementation(jest.fn());
    const rsocketSpy = jest.spyOn(RSocketClient.prototype, 'connect').mockReturnValue({
      subscribe: jest.fn().mockImplementation((rSub) => rSub.onComplete({
        requestStream: () => ({
          subscribe: jest.fn().mockImplementation((sockSub) => {
            sockSub.onSubscribe({request: jest.fn()});
            mockEventSource.subscribe({
              next: (value) => sockSub.onNext({data: value}),
              complete: () => sockSub.onComplete()
            });
          })
        })
      })),
      flatMap: jest.fn(),
      map: jest.fn(),
      then: jest.fn()
    });

    const subscription = LogStream.observe(project)
      .subscribe({
        next: (logEvent) => {
          capturedEvents.push(logEvent);
        },

        complete: () => {
          done();
          subscription.unsubscribe();
        }
      });

    expect(rsocketSpy).toHaveBeenCalled();
    expect(capturedEvents).toHaveLength(sourceEvents.length);
  });

  it('should invoke error callback on connect error', (done) => {
    jest.spyOn(RSocketClient.prototype, 'close').mockImplementation(jest.fn());
    const rsocketSpy = jest.spyOn(RSocketClient.prototype, 'connect').mockReturnValue({
      subscribe: jest.fn().mockImplementation((rSub) => {
        rSub.onError(new Error("mock connect error"));
      }),
      flatMap: jest.fn(),
      map: jest.fn(),
      then: jest.fn()
    });

    const subscriber = {
      complete: done,
      error: jest.fn().mockImplementationOnce(() => {
        done();
      })
    };

    LogStream.observe(project).subscribe(subscriber);
    expect(rsocketSpy).toHaveBeenCalled();
    expect(subscriber.error).toHaveBeenCalled();
    expect(subscriber.error.mock.calls[0][0]).toHaveProperty('on', 'connect');
  });

  it('should invoke error callback on requestStream error', (done) => {
    jest.spyOn(RSocketClient.prototype, 'close').mockImplementation(jest.fn());
    const rsocketSpy = jest.spyOn(RSocketClient.prototype, 'connect').mockReturnValue({
      subscribe: jest.fn().mockImplementation((rSub) => rSub.onComplete({
        requestStream: () => ({
          subscribe: jest.fn().mockImplementation((sockSub) => {
            sockSub.onSubscribe({request: jest.fn()});
            sockSub.onError("mock stream error")
          })
        })
      })),
      flatMap: jest.fn(),
      map: jest.fn(),
      then: jest.fn()
    });

    const subscriber = {
      complete: done,
      error: jest.fn().mockImplementationOnce(() => {
        done();
      })
    };

    LogStream.observe(project).subscribe(subscriber);
    expect(rsocketSpy).toHaveBeenCalled();
    expect(subscriber.error.mock.calls[0][0]).toHaveProperty('on', 'requestStream');
  });
});
