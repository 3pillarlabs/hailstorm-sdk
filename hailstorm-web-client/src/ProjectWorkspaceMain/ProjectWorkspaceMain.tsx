import React, { useState } from 'react';
import { JMeterPlanList } from '../JMeterConfiguration/JMeterPlanList';
import { ClusterList } from '../ClusterConfiguration/ClusterList';
import { ReportsList } from '../ReportsList/ReportsList';
import { ControlPanel } from './ControlPanel';

export const ProjectWorkspaceMain: React.FC = () => {
  const [loadReports, setLoadReports] = useState<boolean>(true);
  const reloadReports = () => setLoadReports(true);

  return (
    <div className="columns workspace-main">
      <div className="column is-3">
        <JMeterPlanList />
        <ClusterList />
      </div>
      <div className="column is-6">
        <ControlPanel {...{reloadReports}} />
      </div>
      <div className="column is-3">
        <ReportsList {...{loadReports, setLoadReports}} />
      </div>
    </div>
  );
}
