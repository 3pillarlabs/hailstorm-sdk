// Subscribe to receive stream updates
import { Project, LogEvent } from './domain';
import { Observable, Subscriber, interval, of, from, zip } from 'rxjs';
import { filter, delayWhen, delay, map } from 'rxjs/operators';
import { DB } from './db';

export const LogStream: {
  _logSource: () => Observable<LogEvent>;
  observe: (project: Project) => Observable<LogEvent>;
} = {
  _logSource: () =>
    zip(from(
      DB.projects
        .filter(project => project.running || project.interimState)
        .flatMap(project => [
          { projectCode: project.code, timestamp: 1565759983, priority: 2, level: "info", message: "Starting Tests..." },
          { projectCode: project.code, timestamp: 1565760004, priority: 2, level: "info", message: "Creating Cluster in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760005, priority: 2, level: "info", message: "Creating Cluster in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760006, priority: 2, level: "info", message: "Creating AMI in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760007, priority: 2, level: "info", message: "Creating AMI in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760008, priority: 2, level: "info", message: "Creating Security Group in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760009, priority: 2, level: "info", message: "Creating Security Group in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760010, priority: 2, level: "info", message: "Creating Instance in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760011, priority: 2, level: "info", message: "Creating Instance in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760014, priority: 2, level: "info", message: "Starting Instance in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760015, priority: 2, level: "info", message: "Starting Instance in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760016, priority: 2, level: "info", message: "Started load generation in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760017, priority: 2, level: "info", message: "Started load generation in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760018, priority: 2, level: "info", message: "Started monitoring database..." },
          { projectCode: project.code, timestamp: 1565760019, priority: 2, level: "info", message: "Started monitoring app server..." },
          { projectCode: project.code, timestamp: 1565760020, priority: 2, level: "info", message: "Stopped load generation in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760021, priority: 2, level: "info", message: "Stopped load generation in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760022, priority: 2, level: "info", message: "Stopped monitoring database..." },
          { projectCode: project.code, timestamp: 1565760023, priority: 2, level: "info", message: "Stopped monitoring app server..." },
          { projectCode: project.code, timestamp: 1565760024, priority: 2, level: "info", message: "Started load generation in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760025, priority: 2, level: "info", message: "Started load generation in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760026, priority: 2, level: "info", message: "Started monitoring database..." },
          { projectCode: project.code, timestamp: 1565760027, priority: 2, level: "info", message: "Started monitoring app server..." },
          { projectCode: project.code, timestamp: 1565760028, priority: 2, level: "info", message: "Stopped load generation in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760029, priority: 2, level: "info", message: "Stopped load generation in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760034, priority: 2, level: "info", message: "Stopped monitoring database..." },
          { projectCode: project.code, timestamp: 1565760404, priority: 2, level: "info", message: "Stopped monitoring app server..." },
          { projectCode: project.code, timestamp: 1565760504, priority: 2, level: "info", message: "Started load generation in us-east-1..." },
          { projectCode: project.code, timestamp: 1565760604, priority: 2, level: "info", message: "Started load generation in us-west-1..." },
          { projectCode: project.code, timestamp: 1565760704, priority: 2, level: "info", message: "Started monitoring database..." },
          { projectCode: project.code, timestamp: 1565768004, priority: 2, level: "info", message: "Started monitoring app server..." },
          { projectCode: project.code, timestamp: 1565769004, priority: 2, level: "info", message: "Stopped load generation in us-east-1..." },
          { projectCode: project.code, timestamp: 1565770004, priority: 2, level: "info", message: "Stopped load generation in us-west-1..." },
          { projectCode: project.code, timestamp: 1565860004, priority: 2, level: "info", message: "Stopped monitoring database..." },
          { projectCode: project.code, timestamp: 1566760004, priority: 2, level: "info", message: "Stopped monitoring app server..." },
        ].map((x) => ({...x, timestamp: Math.random() * 10000000000})))
        .sort((a, b) => a.timestamp - b.timestamp)
    ), interval(1000)).pipe(
      map(([log, _]) => log)
    ),

  observe: function(project) {
    return new Observable((subscriber: Subscriber<LogEvent>) => {
      this._logSource()
        .pipe(filter(log => log.projectCode === project.code))
        .subscribe(log => subscriber.next(log));

      return {
        unsubscribe: () => {
          console.info("Unsubscribe");
        }
      };
    });
  }
};
