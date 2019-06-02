/* eslint-disable jsx-a11y/anchor-is-valid */
import React from 'react';
import './App.scss';
import logo from './AppLogo.png';

function ellipsis({ longText, maxLength = 16 }: { longText: string; maxLength?: number; }): string {
  return longText.length < maxLength ? longText : `${longText.slice(0, maxLength)}...`;
}

const App: React.FC = () => {
  return (
    <>
    <nav className="navbar is-light" role="navigation">
      <div className="container">
        <div className="navbar-brand">
          <a className="navbar-item" href="/projects">
            <span className="app-logo">
              <img src={logo} className="app-logo" alt="HAILSTORM" />
            </span>
          </a>

          <a
            role="button"
            className="navbar-burger burger"
            aria-label="menu"
            aria-expanded="false"
            data-target="navbar-main"
          >
            <span aria-hidden="true" />
            <span aria-hidden="true" />
            <span aria-hidden="true" />
          </a>
        </div>

        <div id="navbar-main" className="navbar-menu">
          <div className="navbar-start">
            <a className="navbar-item">
              <h2>All Projects</h2>
            </a>
            <a className="navbar-item">
              <h2>{ellipsis({ longText: "Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter" })}</h2>
            </a>
            {[
              "Acme Endurance",
              "Acme 30 Burst",
              "Acme 60 Burst",
              "Acme 90 Burst"
            ].map(project => (
              <a className="navbar-item" key={project}>
                <h2>{ellipsis({ longText: project })}</h2>
              </a>
            ))}
            <div className="navbar-item has-dropdown is-hoverable">
              <a className="navbar-link">More</a>
              <div className="navbar-dropdown">
              {[
                "Hailstorm Basic",
                "Cadent Capacity"
              ].map(project => (
                <a className="navbar-item" key={project}>
                  <h2>{ellipsis({ longText: project })}</h2>
                </a>
              ))}
              </div>
            </div>
          </div>

          <div className="navbar-end">
            <div className="navbar-item">
              <a className="button is-link"> New Project </a>
            </div>
          </div>
        </div>
      </div>
    </nav>

    <main>
      <div className="container">
        <div className="columns workspace-header">
          <div className="column is-four-fifths">
            <h2 className="title is-2">
              Hailstorm Basic Priming test with Digital Ocean droplets and custom JMeter
              <sup><i className="fas fa-pen"></i></sup>
            </h2>
          </div>
          <div className="column">
            <h2 className="title is-2 is-status">Running</h2>
          </div>
        </div>

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

        <div className="columns workspace-log">
          <div className="column is-9 is-offset-3">
            <div className="panel">
              <div className="panel-heading">
                <i className="fas fa-info-circle"></i> Log
              </div>
              <div className="panel-block">
                [INFO] Starting Tests... <br/>
                [INFO] Creating Cluster in us-east-1...
              </div>
            </div>
          </div>
        </div>

        <div className="tile notification">
          <a className="button">Back to Projects</a>
        </div>

        <div className="workspace-danger">
          <article className="boundary">
            <h4 className="title is-4">
              <i className="fas fa-exclamation-triangle"></i> Dangerous Settings
            </h4>
            <p className="subtitle">Settings and actions below may result in data loss!</p>
            <p><a className="button is-light is-hovered">Show them &nbsp;<i className="fa fa-angle-up"></i></a></p>
          </article>

          <article className="message is-danger">
            <div className="message-body">
              <div className="columns">
                <div className="column is-3">
                  <button className="button is-danger">
                    <i className="fas fa-trash"></i>&nbsp; Delete this project
                  </button>
                </div>
                <div className="column is-9">
                  <article>
                    <p>
                      If you delete this project, you will not be able to run the tests within. Please ensure:
                    </p>
                    <ul>
                      <li key="line-1">Data you need is exported.</li>
                      <li key="line-2">There are no on-going operations.</li>
                      <li key="line-3">The setup has been terminated.</li>
                    </ul>
                  </article>
                </div>
              </div>
            </div>
          </article>
        </div>
      </div>
    </main>
    </>
  );
}

export default App;
