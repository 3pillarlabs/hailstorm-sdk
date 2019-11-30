// Subscribe to receive stream updates
import { Project, LogEvent } from './domain';
import { Observable, Subscriber } from 'rxjs';
import { filter } from 'rxjs/operators';
import { RSocketClient, JsonSerializer, IdentitySerializer} from 'rsocket-core';
import RSocketWebSocketClient from 'rsocket-websocket-client';

const MAX_REQUEST_VALUE = 2147483647;

export const LogStream: {
  _logSource: () => Observable<LogEvent>;
  observe: (project: Project) => Observable<LogEvent>;
} = {

  _logSource: () => {
    const client = new RSocketClient({
      serializers: {
        data: JsonSerializer,
        metadata: IdentitySerializer
      },
      setup: {
        metadataMimeType: "message/x.rsocket.routing.v0",
        dataMimeType: "application/json",
        keepAlive: 60000,
        lifetime: 180000
      },
      transport: new RSocketWebSocketClient({url: "ws://localhost:8080/rsocket"})
    });

    return new Observable((subscriber: Subscriber<LogEvent>) => {
      client.connect()
        .subscribe({
          onComplete: function(socket) {
            socket.requestStream({
              metadata: String.fromCharCode("logs".length) + "logs"
            }).subscribe({
                onComplete: () => {
                  subscriber.complete();
                },

                onError: (reason) => {
                  subscriber.error({reason, on: 'requestStream'});
                },

                onNext: (logEvent) => {
                  subscriber.next(logEvent.data);
                },

                onSubscribe: (subscription) => {
                  subscription.request(MAX_REQUEST_VALUE);
                }
            });
          },

          onError: (reason) => {
            subscriber.error({reason, on: 'connect'});
          }
        });

      return {
        unsubscribe: () => {
          client.close();
        }
      }
    });
  },

  observe: function(project) {
    return this._logSource()
      .pipe(
        filter(log => log.projectCode === project.code || !log.projectCode)
      );
  }
};
