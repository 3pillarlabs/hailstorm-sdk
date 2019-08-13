import React, { useContext, useState, useEffect } from 'react';
import { ActiveProjectContext } from '../ProjectWorkspace/ProjectWorkspace';
import { Report } from '../domain';
import { Loader } from '../Loader/Loader';
import { ApiFactory } from '../api';

export interface ReportListProps {
  loadReports: boolean;
  setLoadReports: React.Dispatch<React.SetStateAction<boolean>>;
}

export const ReportsList: React.FC<ReportListProps> = (props) => {
  const {loadReports, setLoadReports} = props;
  const {project} = useContext(ActiveProjectContext);
  const [reports, setReports] = useState<Report[]>([]);

  useEffect(() => {
    if (!loadReports) return;
    ApiFactory()
      .reports()
      .list(project.id)
      .then(setReports)
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
      reports.map(({title}) => (
        <a className="panel-block" key={title}>
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
