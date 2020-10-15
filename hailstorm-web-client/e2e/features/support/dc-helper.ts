import { connect as sockConnect} from 'net';
import { get as httpGet } from 'http';

export async function httpOK(url: string): Promise<boolean> {
  return new Promise((resolve, _reject) => {
    httpGet(`http://${url}`, (res) => {
      const {statusCode} = res;
      res.resume();
      if (statusCode >= 200 && statusCode < 400) {
        resolve(true);
      } else {
        resolve(false);
      }
    }).on('error', (error) => {
      console.error(error);
      resolve(false);
    });
});
}

export async function socketOK(hostOrIp: string, port: number): Promise<boolean> {
  return new Promise<boolean>((resolve, _reject) => {
    try {
      const client = sockConnect(port, hostOrIp, () => {
        resolve(true);
      });

      client.once('error', () => {
        resolve(false);
      });

      setTimeout(() => client.destroy(), 100);
    } catch (error) {
      resolve(false);
    }
  });
}
