import React, { useState, useEffect } from 'react';
import { Project, Report } from '../domain';
import { Loader } from '../Loader';
import { ApiFactory } from '../api';
import styles from './ReportsList.module.scss';

export interface ReportListProps {
  loadReports: boolean;
  setLoadReports: React.Dispatch<React.SetStateAction<boolean>>;
  project: Project;
  waitingForReport?: boolean;
}

export const ReportsList: React.FC<ReportListProps> = ({
  loadReports,
  setLoadReports,
  project,
  waitingForReport
}) => {
  const [reports, setReports] = useState<Report[]>([]);
  const [newReportInProgress, setNewReportInProgress] = useState<boolean>();
  const [newLabel, setNewLabel] = useState(false);

  useEffect(() => {
    if (!loadReports) return;
    ApiFactory()
      .reports()
      .list(project.id)
      .then((fetched) => setReports(fetched.sort((a, b) => b.title.localeCompare(a.title))))
      .then(() => setLoadReports(false))
  }, [loadReports]);

  useEffect(() => {
    if (newReportInProgress && !waitingForReport) {
      setNewLabel(true);
    }

    setNewReportInProgress(waitingForReport);
  }, [waitingForReport]);

  return (
    <div className="panel" data-testid="Reports List">
      <div className="panel-heading">
        <i className="fas fa-chart-pie"></i> Reports
      </div>
      <div className={styles.panelBody}>
        {waitingForReport && (
          <div className="panel-block force-wrap">
            <progress className="progress is-small is-primary" max="100">
              Report generation in progress
            </progress>
          </div>
        )}
        {loadReports ?
        <Loader /> :
        (reports.length ?
        reports.map(({title, uri}, index) => (
          <a className="panel-block force-wrap" key={title} href={uri} target="_blank">
            <span className="panel-icon">
              <i className="far fa-file-word" aria-hidden="true"></i>
            </span>
            {title} {index === 0 && newLabel && (<span className="tag is-info">new</span>)}
          </a>
        )) :
        <div className="panel-block">
          <div className="notification">No reports as yet.</div>
        </div>
        )}
      </div>
    </div>
  );
}
