import React, { useContext, useState, useEffect } from 'react';
import { Report } from '../domain';
import { Loader } from '../Loader/Loader';
import { ApiFactory } from '../api';
import { AppStateContext } from '../appStateContext';

export interface ReportListProps {
  loadReports: boolean;
  setLoadReports: React.Dispatch<React.SetStateAction<boolean>>;
}

export const ReportsList: React.FC<ReportListProps> = (props) => {
  const {loadReports, setLoadReports} = props;
  const {appState} = useContext(AppStateContext);
  const project = appState.activeProject!;
  const [reports, setReports] = useState<Report[]>([]);

  useEffect(() => {
    if (!loadReports) return;
    ApiFactory()
      .reports()
      .list(project.id)
      .then((fetched) => setReports(fetched.sort((a, b) => b.title.localeCompare(a.title))))
      .then(() => setLoadReports(false))
  }, [loadReports]);

  return (
    <div className="panel">
      <div className="panel-heading">
        <i className="fas fa-chart-pie"></i> Reports
      </div>
      {loadReports ?
      <Loader /> :
      (reports.length ?
      reports.map(({title, uri}) => (
        <a className="panel-block" key={title} href={uri} target="_blank">
          <span className="panel-icon">
            <i className="far fa-file-word" aria-hidden="true"></i>
          </span>
          {title}
        </a>
      )) :
      <div className="panel-block">
        <div className="notification">No reports as yet.</div>
      </div>
      )}
    </div>
  );
}
