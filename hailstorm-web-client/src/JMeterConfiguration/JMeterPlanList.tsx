import React from 'react';
import { JMeter } from '../domain';
import { Loader } from '../Loader';

export interface JMeterPlanListProps {
  showEdit?: boolean;
  jmeter: JMeter;
  dispatch?: React.Dispatch<any>;
}

export const JMeterPlanList: React.FC<JMeterPlanListProps> = ({
  showEdit,
  jmeter,
  dispatch
}) => {
  const defaultVersion = jmeter ? jmeter.version : undefined;
  return (
    <div className="panel">
      <div className="panel-heading">
        <div className="level">
          <div className="level-left">
            <div className="level-item">
              <i className="fas fa-feather-alt"></i> JMeter
            </div>
          </div>
          <div className="level-right">
            <div className="level-item">
              {showEdit ? <a className="button is-small"><i className="far fa-edit"></i> Edit</a> : null}
            </div>
          </div>
        </div>
      </div>
      {renderPlanList(jmeter)}
    </div>
  );
}

function renderPlanList(jmeter: JMeter): React.ReactNode {
  return jmeter.files.map((plan) => (
    <a className="panel-block" key={plan.id}>
      <span className="panel-icon">
        <i className="far fa-file-code" aria-hidden="true"></i>
      </span>
      {plan.name}
    </a>
  ));
}
