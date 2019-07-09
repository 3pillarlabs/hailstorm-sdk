import React from 'react';

export const JMeterPlanList: React.FC = () => {
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
              <a className="button is-small"><i className="far fa-edit"></i> Edit</a>
            </div>
          </div>
        </div>
      </div>
      {[
        "hailstorm-site-basic",
        "hailstorm-site-admin"
      ].map(planName => (
        <a className="panel-block" key={planName}>
          <span className="panel-icon">
            <i className="far fa-file-code" aria-hidden="true"></i>
          </span>
          {planName}
        </a>
      ))}
    </div>
  );
}
