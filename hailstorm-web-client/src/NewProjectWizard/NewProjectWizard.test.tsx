import React from 'react';
import { shallow, mount } from 'enzyme';
import { NewProjectWizard } from './NewProjectWizard';
import { MemoryRouter, Route } from 'react-router';
import { AppStateContext } from '../appStateContext';
import { WizardTabTypes, AppState } from '../store';
import { ActivateTabAction, ProjectSetupCancelAction, StayInProjectSetupAction } from './actions';
import { reducer } from './reducer';
import { Link } from 'react-router-dom';

jest.mock('../ProjectConfiguration', () => ({
  __esModule: true,
  ProjectConfiguration: (() => (
    <div id="projectConfiguration">
    </div>
  )) as React.FC
}));

jest.mock('../JMeterConfiguration', () => ({
  __esModule: true,
  JMeterConfiguration: (() => (
    <div id="jmeterConfiguration">
    </div>
  )) as React.FC
}));

jest.mock('../ClusterConfiguration', () => ({
  __esModule: true,
  ClusterConfiguration: (() => (
    <div id="clusterConfiguration">
    </div>
  )) as React.FC
}));

jest.mock('./SummaryView', () => ({
  __esModule: true,
  SummaryView: (() => (
    <div id="summaryView">
    </div>
  )) as React.FC
}));

jest.mock('../Modal', () => ({
  __esModule: true,
  Modal: (({isActive, children}) => (
    (isActive ? <div id="modal">{children}</div> : null)
  )) as React.FC<{isActive: boolean}>
}));

describe('<NewProjectWizard />', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    shallow(<NewProjectWizard />);
  });

  it('should show the current step', () => {
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      },
      activeProject: undefined
    };

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component.find('WizardStepTitle').at(0)).toHaveProp('isActive', true);
    expect(component.find('WizardStepTitle').at(0).prop('done')).toBeFalsy();
  });

  it('should show completed steps', () => {
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {[WizardTabTypes.Project]: true}
      },
      activeProject: { id: 1, code: 'a', title: 'A', running: false, autoStop: false }
    };

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component.find('WizardStepTitle').at(0)).toHaveProp('done', true);
  });

  it('should show remaining steps', () => {
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {[WizardTabTypes.Project]: true}
      },
      activeProject: { id: 1, code: 'a', title: 'A', running: false, autoStop: false }
    };

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component.find('WizardStepTitle').at(1)).toHaveProp('isActive', false);
    expect(component.find('WizardStepTitle').at(1).prop('done')).toBeFalsy();
  });

  it('should not navigate to remaining steps', () => {
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {[WizardTabTypes.Project]: true}
      },
      activeProject: { id: 1, code: 'a', title: 'A', running: false, autoStop: false }
    };

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component.find('.stepList')).toContainMatchingElements(2, 'Link');
  });

  it('should move backward to all previous steps', () => {
    let appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Review,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
        }
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    };

    const dispatch = jest.fn().mockImplementation((action: any) => {
      appState = reducer(appState, action);
    });

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component).toContainMatchingElements(4, 'Link');

    component.find('Link').at(2).simulate('click', {button: 0});
    component.update();
    expect(dispatch.mock.calls[0][0]).toBeInstanceOf(ActivateTabAction);
    expect((dispatch.mock.calls[0][0] as ActivateTabAction).payload).toEqual(WizardTabTypes.Cluster);

    component.find('Link').at(1).simulate('click', {button: 0});
    component.update();
    expect((dispatch.mock.calls[1][0] as ActivateTabAction).payload).toEqual(WizardTabTypes.JMeter);

    component.find('Link').at(0).simulate('click', {button: 0});
    component.update();
    expect((dispatch.mock.calls[2][0] as ActivateTabAction).payload).toEqual(WizardTabTypes.Project);
  });

  it('should display loader when wizardState is not set', () => {
    const appState: AppState = { runningProjects: [], activeProject: undefined };
    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component).toContainExactlyOneMatchingElement('Loader');
  });

  it('should display cluster configuration', () => {
    let appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
        }
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    };

    const dispatch = jest.fn().mockImplementation((action: any) => {
      appState = reducer(appState, action);
    });

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component.find('WizardStepTitle').at(2)).toHaveProp('isActive', true);
  });

  it('should cancel to project list if the wizard was not started or exited', () => {
    const appState: AppState = {
      runningProjects: [],
      activeProject: undefined
    };

    const ProjectList = () => (
      <div id="projectList"></div>
    );

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/wizard/project/new']}>
          <NewProjectWizard />
          <Route exact path="/projects" component={ProjectList} />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    expect(component).toContainExactlyOneMatchingElement('#projectList');
  });

  it('should redirect to project workspace when wizard completes', () => {
    const appState: AppState = {
      runningProjects: [],
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    };

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/wizard/project/1/review']}>
          <NewProjectWizard />
          <Route exact path="/projects/1">
            <div id="project1"></div>
          </Route>
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    expect(component).toContainExactlyOneMatchingElement('#project1');
  });

  it('should prompt if the user navigates out of the wizard', () => {
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
        }
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    };

    const ProjectList = () => (
      <div id="projectList"></div>
    );

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/wizard/projects/1/clusters']}>
          <NewProjectWizard />
          <Link id="linkToProjects" to="/projects">Projects</Link>
          <Route exact path="/projects" component={ProjectList} />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component).not.toContainMatchingElement('#projectList');
    component.find('Link#linkToProjects').simulate('click', {button: 0});
    expect(component).not.toContainMatchingElement('#projectList');
  });

  it('should prompt to confirm cancel of wizard', () => {
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {},
        confirmCancel: true
      },
      activeProject: undefined
    };

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    expect(component).toContainExactlyOneMatchingElement('#modal');
  });

  it('should cancel the setup if the user exits the wizard', () => {
    jest.useFakeTimers();
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
        },
        confirmCancel: true
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    };

    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    jest.runAllTimers();
    component.update();
    expect(component).toContainExactlyOneMatchingElement('#modal');
    console.debug(component.html());
    component.find('#modal button').simulate('click');
    expect(dispatch).toBeCalled();
    expect(dispatch.mock.calls[0][0]).toBeInstanceOf(ProjectSetupCancelAction);
  });

  it('should stay in the setup if the user does not confirm exiting the wizard', () => {
    const appState: AppState = {
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
        },
        confirmCancel: true
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    };

    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <MemoryRouter>
          <NewProjectWizard />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    expect(component).toContainExactlyOneMatchingElement('#modal');
    component.find('#modal a').simulate('click');
    expect(dispatch).toBeCalled();
    expect(dispatch.mock.calls[0][0]).toBeInstanceOf(StayInProjectSetupAction);
  });
});
