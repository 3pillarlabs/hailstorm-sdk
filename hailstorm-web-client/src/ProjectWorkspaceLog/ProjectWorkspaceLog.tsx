import React, { useContext, useState, useEffect, useRef } from 'react';
import styles from './ProjectWorkspaceLog.module.scss';
import { LogEvent } from '../domain';
import { LogStream } from '../log-stream';
import { AppStateContext } from '../appStateContext';
import { LogOptions } from './LogOptions';
import _ from 'lodash';
import { AppNotificationContextProps, useNotifications } from '../app-notifications';

const DEFAULT_SCROLL_LIMIT = 500;

function trimLogs(logs: LogEvent[], limit: number): LogEvent[] {
  const currentLogs = [...logs];
  if (limit >= logs.length) return currentLogs;

  _.times(logs.length - limit, () => currentLogs.shift());
  return currentLogs;
}

function appendLog({
  log,
  setLogs,
  appendLimit,
  isVerbose,
  notifiers
}: {
  log: LogEvent;
  setLogs: React.Dispatch<React.SetStateAction<LogEvent[]>>;
  appendLimit: number;
  isVerbose: boolean;
  notifiers: AppNotificationContextProps;
}) {
  setLogs((stateLogs) => {
    const currentLogs = trimLogs(stateLogs, appendLimit - 1);
    if (log.level !== 'debug' || (log.level === 'debug' && isVerbose)) {
      currentLogs.push(log);
    }

    if (log.level === 'warn') {
      notifiers.notifyWarning(log.message);
    }

    if (log.level === 'error' || log.level === 'fatal') {
      notifiers.notifyError(log.message);
    }

    return currentLogs;
  });
};

export const ProjectWorkspaceLog: React.FC<{
  scrollLimit?: number;
}> = ({
  scrollLimit
}) => {
  const {appState} = useContext(AppStateContext);
  const notifiers = useNotifications();
  const project = appState.activeProject!;
  const [logs, setLogs] = useState<LogEvent[]>([]);
  const [appendLimit, setAppendLimit] = useState<number>(scrollLimit || DEFAULT_SCROLL_LIMIT);
  const [isVerbose, setIsVerbose] = useState(false);

  const changeAppendLimit: (newAppendLimit: number) => void = (newAppendLimit) => {
    setAppendLimit(newAppendLimit);
    if (newAppendLimit < logs.length) {
      setLogs(trimLogs(logs, newAppendLimit));
    }
  };

  const logBox = useRef<HTMLDivElement>(null);

  useEffect(() => {
    console.debug('ProjectWorkspaceLog#useEffect(scrollLimit)');
    if (scrollLimit) setAppendLimit(scrollLimit);
  }, [scrollLimit]);

  useEffect(() => {
    console.debug('ProjectWorkspaceLog#useEffect(project.id)');
    const subscription = LogStream.observe(project).subscribe({
      next: (log) => {
        appendLog({ log, setLogs, appendLimit, isVerbose, notifiers });
        if (window && logBox && logBox.current) {
          const scrollY = window.getComputedStyle && window.getComputedStyle(logBox.current).lineHeight;
          if (scrollY && logBox.current.scrollBy) logBox.current.scrollBy(0, parseInt(scrollY));
        }
      },

      error: (error) => {
        let message: string;
        let reason: any | undefined = undefined;
        if (error instanceof Error) {
          message = error.message;
          reason = error;
        } else if (error instanceof Object) {
          message = `Unknown error occurred. Most likely connection to the message hub was lost`;
        } else {
          message = error.toString();
        }

        if (reason) {
          notifiers.notifyError(message, reason);
        } else {
          notifiers.notifyWarning(message);
        }
      }
    });

    return () => {
      console.debug('ProjectWorkspaceLog#useEffect unmount');
      subscription.unsubscribe();
    }
  }, [project.id, isVerbose, appendLimit]);

  return (
    <div className="columns">
      <div className="column is-9 is-offset-3">
        <div className="panel">
          <div className="panel-heading">
            <div className="columns">
              <div className="column is-3">
                <i className="fas fa-info-circle" /> Log
              </div>
              <div className="column is-offset-7 is-2">
                <LogOptions
                  onClear={() => setLogs([])}
                  onChangeScrollLimit={changeAppendLimit}
                  verbose={isVerbose}
                  setVerbose={setIsVerbose}
                />
              </div>
            </div>
          </div>
          <div className={`panel-block ${styles.logBox}`} ref={logBox}>
            {logs.map((log) => (
              <div key={log.id || log.timestamp} className={styles[log.level]}>
                [{log.level.toUpperCase()}] {log.message}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
