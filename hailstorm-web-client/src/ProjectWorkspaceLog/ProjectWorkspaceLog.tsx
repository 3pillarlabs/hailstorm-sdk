import React, { useContext, useState, useEffect, useRef } from 'react';
import styles from './ProjectWorkspaceLog.module.scss';
import { LogEvent } from '../domain';
import { LogStream } from '../stream';
import { AppStateContext } from '../appStateContext';

export const ProjectWorkspaceLog: React.FC = () => {
  const {appState} = useContext(AppStateContext);
  const project = appState.activeProject!;
  const [logs, setLogs] = useState<LogEvent[]>([]);
  const appendLog = (log: LogEvent) => {
    setLogs((logs) => [...logs, log]);
  };

  const logBox = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!project.running && !project.interimState) return;
    console.debug('ProjectWorkspaceLog#useEffect');
    const subscription = LogStream.observe(project).subscribe({
      next: (log) => {
        appendLog(log);
        if (window && logBox && logBox.current) {
          const scrollY = window.getComputedStyle && window.getComputedStyle(logBox.current).lineHeight;
          if (scrollY) logBox.current.scrollBy(0, parseInt(scrollY));
        }
      }
    });

    return () => subscription.unsubscribe();
  }, [project]);

  return (
    <div className="columns">
      <div className="column is-9 is-offset-3">
        <div className="panel">
          <div className="panel-heading">
            <i className="fas fa-info-circle" /> Log
          </div>
          <div className={`panel-block ${styles.logBox}`} ref={logBox}>
            {logs.map((log) => (
              <React.Fragment key={log.timestamp}>[{log.level.toUpperCase()}] {log.message} <br/></React.Fragment>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
