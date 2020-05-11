import React from 'react';
import { shallow, mount } from 'enzyme';
import { ProjectWorkspaceMain } from './ProjectWorkspaceMain';
import { AppStateContext } from '../appStateContext';
import { ClusterService } from "../services/ClusterService";
import { JMeterService } from "../services/JMeterService";
import { JMeter, Cluster, AmazonCluster, InterimProjectState } from '../domain';
import { MemoryRouter, Route, RouteComponentProps } from 'react-router';
import { ReportService } from '../services/ReportService';
import { ExecutionCycleService } from '../services/ExecutionCycleService';

describe('<ProjectWorkspaceMain />', () => {
  let jmeterPromise: Promise<JMeter>;
  let clustersPromise: Promise<Cluster[]>;

  beforeEach(() => {
    jest.resetAllMocks();
  });

  beforeEach(() => {
    jmeterPromise = Promise.resolve<JMeter>({files: [
      {id: 1, name: 'data.csv', dataFile: true}
    ]});

    jest.spyOn(JMeterService.prototype, "list").mockReturnValue(jmeterPromise);
  });

  beforeEach(() => {
    clustersPromise = Promise.resolve<Cluster[]>([
      {
        id: 23,
        code: 'smiling-ninja-23',
        type: 'AWS',
        title: '',
        accessKey: 'A',
        secretKey: 'S',
        instanceType: 't2.small',
        maxThreadsByInstance: 25,
        region: 'sa-east-11'
      } as AmazonCluster
    ]);

    jest.spyOn(ClusterService.prototype, "list").mockReturnValue(clustersPromise);
  });

  beforeEach(() => {
    jest.spyOn(ExecutionCycleService.prototype, 'list').mockResolvedValue([]);
  })

  beforeEach(() => {
    jest.spyOn(ReportService.prototype, 'list').mockResolvedValue([]);
  });

  it('should render without crashing', () => {
    shallow(<ProjectWorkspaceMain />);
  });

  it('should load JMeter configuration if not loaded', async () => {
    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false},
          },
          dispatch
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    component.update();
    await jmeterPromise;
    expect(dispatch).toBeCalledTimes(2);
    const action = dispatch.mock.calls[0][0] as {payload: JMeter};
    expect(action.payload).toHaveProperty('files');
  });

  it('should load Cluster configuration if not loaded', async () => {
    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false},
          },
          dispatch
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    component.update();
    await clustersPromise;
    expect(dispatch).toBeCalledTimes(2);
    const action = dispatch.mock.calls[1][0] as {payload: Cluster[]};
    expect(action.payload.length).toEqual(1);
  });

  it('should disable JMeter Edit when project is running', async () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [
              {id: 1, code: 'a', title: 'A', running: true}
            ],
            activeProject: {id: 1, code: 'a', title: 'A', running: true},
          },
          dispatch: jest.fn()
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    component.update();
    expect(component.find('JMeterPlanList')).toHaveProp('disableEdit', true);
  });

  it('should disable JMeter Edit when project has an interim state', async () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false, interimState: InterimProjectState.STARTING},
          },
          dispatch: jest.fn()
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    component.update();
    expect(component.find('JMeterPlanList')).toHaveProp('disableEdit', true);
  });

  it('should disable Cluster Edit when project is running', async () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [
              {id: 1, code: 'a', title: 'A', running: true}
            ],
            activeProject: {id: 1, code: 'a', title: 'A', running: true},
          },
          dispatch: jest.fn()
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    component.update();
    expect(component.find('ClusterList')).toHaveProp('disableEdit', true);
  });

  it('should disable Cluster Edit when project has an interim state', async () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false, interimState: InterimProjectState.STARTING},
          },
          dispatch: jest.fn()
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    component.update();
    expect(component.find('ClusterList')).toHaveProp('disableEdit', true);
  });

  it('should edit JMeter plans', () => {
    const NewProjectWizard = () => (
      <div id="NewProjectWizard"></div>
    );

    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false},
          },
          dispatch
        }}
      >
        <MemoryRouter>
          <ProjectWorkspaceMain />
          <Route exact path="/wizard/projects/:id/jmeter_plans" component={NewProjectWizard} />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    component.find('JMeterPlanList button').simulate('click');
    component.update();
    expect(component).toContainExactlyOneMatchingElement("#NewProjectWizard");
  });

  it('should edit Clusters', () => {
    const NewProjectWizard = ({location}: RouteComponentProps) => (
      <div id="NewProjectWizard">
        {Object.keys(location.state).map((stateKey) => (<div key={stateKey}>
          {stateKey} |
        </div>))}
      </div>
    );

    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false},
          },
          dispatch
        }}
      >
        <MemoryRouter>
          <ProjectWorkspaceMain />
          <Route exact path="/wizard/projects/:id/clusters" component={NewProjectWizard} />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    component.find('ClusterList button').simulate('click');
    component.update();
    expect(component).toContainExactlyOneMatchingElement("#NewProjectWizard");
  });

  it('should show "Live" status text when project is live', () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false, live: true},
          },
          dispatch: jest.fn()
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    expect(component).toContainExactlyOneMatchingElement('TerminateProject');
  });

  it('should show "Live" status text when project interim state is terminating', () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {
              id: 1,
              code: "a",
              title: "A",
              running: true,
              interimState: InterimProjectState.TERMINATING,
            },
          },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    expect(component).toContainExactlyOneMatchingElement('TerminateProject');
  });

  it('should not show "Live" status text when project is running', () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {
              id: 1,
              code: "a",
              title: "A",
              running: true
            },
          },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    expect(component).not.toContainExactlyOneMatchingElement('TerminateProject');
  });

  it('should not show "Live" status text when project interim state is not terminating', () => {
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {
              id: 1,
              code: "a",
              title: "A",
              running: true,
              interimState: InterimProjectState.STOPPING
            },
          },
          dispatch: jest.fn(),
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    expect(component).not.toContainExactlyOneMatchingElement('TerminateProject');
  });
});
