import React from 'react';
import { TopNav } from './TopNav';
import { shallow, mount } from 'enzyme';
import { MemoryRouter } from 'react-router';
import { AppStateContext } from '../appStateContext';
import { AppState } from '../store';
import { Project } from '../domain';
import { ProjectBarProps } from '../ProjectBar/ProjectBar';
import { ModifyRunningProjectAction } from './actions';
import { WizardTabTypes } from "../NewProjectWizard/domain";
import { ProjectService } from '../services/ProjectService';

jest.mock('../ProjectBar', () => {
  return {
    __esModule: true,
    ProjectBar: ({runningProjects}: ProjectBarProps) => (
      <div id="projectBar">
      {runningProjects.map(({id, code, title}) => (
        <div key={id}>
          <span className="code">{code}</span>
          <span className="title">{title}</span>
        </div>
      ))}
      </div>
    )
  }
});

describe('<TopNav />', () => {
  let projectSpy: jest.SpyInstance<Promise<Project[]>>;

  beforeEach(() => {
    projectSpy = jest.spyOn(ProjectService.prototype, 'list').mockResolvedValue([]);
  })

  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    shallow(<TopNav/>);
  });

  it('should toggle burger menu', () => {
    const component = mount(
      <MemoryRouter>
        <TopNav />
      </MemoryRouter>
    );
    expect(component).toContainExactlyOneMatchingElement('a.navbar-burger');
    expect(component.find('.navbar-menu')).not.toHaveClassName('is-active');
    component.find('a.navbar-burger').simulate('click', { currentTarget: { classList: { toggle: jest.fn() } } });
    expect(component.find('.navbar-menu')).toHaveClassName('is-active');
  });

  it('should reload running projects if location is not projects list', () => {
    mount(
      <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: undefined}, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/projects/2']}>
          <TopNav />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(projectSpy).toBeCalled();
  });

  it('should not reload running projects if location is projects list', () => {
    mount(
      <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: undefined}, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/projects']}>
          <TopNav />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(projectSpy).not.toBeCalled();
  });

  it('should disable new project button in new project wizard', () => {
    const appState: AppState = {
      runningProjects: [],
      activeProject: undefined,
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      }
    };

    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/wizard/project/new']}>
          <TopNav />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(component.find('button')).toExist();
    expect(component.find('button')).toBeDisabled();
  });

  it('change in active project title should reflect in project bar', () => {
    const project: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: true};
    const appState: AppState = {
      runningProjects: [ project ],
      activeProject: {...project, title: 'B'}
    };

    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <MemoryRouter initialEntries={['/projects/2']}>
          <TopNav />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    component.update();
    expect(dispatch).toBeCalled();
    const callAction = dispatch.mock.calls[0][0];
    expect(callAction).toBeInstanceOf(ModifyRunningProjectAction);
    expect((callAction as ModifyRunningProjectAction).payload.attrs).toEqual({title: 'B'});
  });
});
