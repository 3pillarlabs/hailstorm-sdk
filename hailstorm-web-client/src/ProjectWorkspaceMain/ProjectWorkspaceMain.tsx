import React from 'react';

export const ProjectWorkspaceMain: React.FC = () => {
  return (
    <div className="columns workspace-main">
      <div className="column is-3">
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

        <div className="panel">
          <div className="panel-heading">
            <div className="level">
              <div className="level-left">
                <div className="level-item">
                  <i className="fas fa-globe-americas"></i> Clusters
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
            "AWS us-east-1",
            "AWS us-west-1",
            "Bob's Datacenter"
          ].map(clusterTitle => (
            <a className="panel-block" key={clusterTitle}>
              <span className="panel-icon">
                <i className="fas fa-server" aria-hidden="true"></i>
              </span>
              {clusterTitle}
            </a>
          ))}
        </div>
      </div>
      <div className="column is-6">
        <div className="panel">
          <div className="panel-heading">
            <i className="fas fa-flask"></i> Tests
          </div>
          <div className="panel-block">
            <div className="level">
              <div className="level-left">
                <div className="level-item">
                  <button className="button is-small is-light"><i className="fas fa-stop-circle"></i> Stop</button>
                </div>
                <div className="level-item">
                  <button className="button is-small is-danger"><i className="fa fa-ban"></i> Abort</button>
                </div>
              </div>
              <div className="level-right">
                <div className="level-item">
                  <a className="button is-small"><i className="fas fa-chart-line"></i> Report</a>
                </div>
                <div className="level-item">
                  <a className="button is-small"><i className="fas fa-download"></i> Export</a>
                </div>
                <div className="level-item">
                  <button className="button is-small is-primary" disabled><i className="fas fa-play-circle"></i> Start</button>
                </div>
              </div>
            </div>
          </div>
          <div className="panel-block">
            <table className="table is-fullwidth is-striped">
              <thead>
                <tr>
                  <th><input type="checkbox"></input></th>
                  <th>Threads</th>
                  <th className="is-gtk">90th Percentile (ms)</th>
                  <th className="is-gtk">Throughput (tps)</th>
                  <th>Started</th>
                  <th>Duration</th>
                  <th className="is-gtk"></th>
                </tr>
              </thead>
              <tbody>
                {[
                  {
                    threadsCount: 100,
                    responseTime: 774.78,
                    tps: 2145.34,
                    startedAt: "Yesterday 10:00 am",
                    duration: ""
                  },
                  {
                    threadsCount: 80,
                    responseTime: 674.78,
                    tps: 2345.34,
                    startedAt: "Mon 27/05 5:00 pm",
                    duration: "30m:10s"
                  }
                ].map(({threadsCount, responseTime, tps, startedAt, duration}) => (
                <tr key={threadsCount.toString()}>
                  <td><input type="checkbox"></input></td>
                  <td>{threadsCount}</td>
                  <td className="is-gtk">{responseTime}</td>
                  <td className="is-gtk">{tps}</td>
                  <td>{startedAt}</td>
                  <td>{duration}</td>
                  <td className="is-gtk"><a className="is-danger"><i className="fas fa-trash"></i></a></td>
                </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="panel-block is-gtk">
            <div className="level">
              <div className="level-left">
              </div>
              <div className="level-right">
                <div className="level-item">
                  <a className="button is-small"><i className="fas fa-trash-restore"></i> Restore</a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="column is-3">
        <div className="panel">
          <div className="panel-heading">
            <i className="fas fa-chart-pie"></i> Reports
          </div>
          {[
            "hailstorm-site-basic-1-2",
            "hailstorm-site-basic-2-5",
            "hailstorm-site-basic-1-5",
          ].map(reportFileName => (
            <a className="panel-block" key={reportFileName}>
              <span className="panel-icon">
                <i className="far fa-file-word" aria-hidden="true"></i>
              </span>
              {reportFileName}
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}
