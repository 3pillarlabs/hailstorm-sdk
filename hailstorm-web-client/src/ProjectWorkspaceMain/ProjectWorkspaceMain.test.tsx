import React from 'react';
import { shallow, mount } from 'enzyme';
import { ProjectWorkspaceMain } from './ProjectWorkspaceMain';
import { AppStateContext } from '../appStateContext';
import { ClusterService } from "../services/ClusterService";
import { JMeterService } from "../services/JMeterService";
import { JMeter, Cluster, AmazonCluster, InterimProjectState } from '../domain';
import { MemoryRouter, Route } from 'react-router';

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
          <Route exact path="/wizard/projects/:id/clusters" component={NewProjectWizard} />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    component.find('ClusterList button').simulate('click');
    component.update();
    expect(component).toContainExactlyOneMatchingElement("#NewProjectWizard");
  });
});
