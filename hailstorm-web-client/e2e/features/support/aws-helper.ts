import * as fs from 'fs';
import * as YAML from 'yaml';
import * as AWS from 'aws-sdk';
import * as http from 'http';
import * as path from 'path';

export function awsKeys(): {access_key: string, secret_key: string} {
  const fileContents = fs.readFileSync('data/keys.yml', 'utf8');
  return YAML.parse(fileContents);
}

export function taggedInstance(
  tag: string,
  region: string = "us-east-1",
  status: string = "running",
  tagKey: string = "Name"
): Promise<AWS.EC2.Instance> {
  const keys = awsKeys();
  const ec2 = new AWS.EC2({
    accessKeyId: keys.access_key,
    secretAccessKey: keys.secret_key,
    region
  });

  return new Promise<AWS.EC2.Instance>((resolve, reject) => {
    ec2.describeInstances(
      {
        Filters: [{Name: 'instance-state-name', Values: [status]}]
      },
      (err, data) => {
        if (err) {
          reject(err);
          return;
        }

        const match = data.Reservations.reduce(
          (s, e) => {
            s.push(...e.Instances);
            return s;
          }, ([] as AWS.EC2.Instance[])
        ).find(
          instance =>
            instance.Tags.find(t => t.Key === tagKey && t.Value.match(new RegExp(tag)))
        );

        resolve(match);
      }
    );
  });
}

export function checkHttpReach(address: string): Promise<boolean> {
  console.debug(address);
  return new Promise<boolean>((resolve, reject) => {
    http
      .get(`http://${address}`, (res) => {
        const { statusCode } = res;
        res.resume();
        resolve(statusCode === 200);
      })
      .on('error', (err) => {
        reject(err);
      });
  });
}

export function buildPath(): string {
  return path.resolve('build');
}

export function writeServerIP(ipAddress: string, namePrefix: string) {
  fs.writeFileSync(serverIPFilePath(namePrefix), ipAddress);
}

function serverIPFilePath(namePrefix: string): string {
  return path.resolve(buildPath(), `${namePrefix}-server-ip.txt`);
}

export function readServerIP(namePrefix: string): string {
  return fs.readFileSync(serverIPFilePath(namePrefix), { encoding: 'utf-8' });
}
