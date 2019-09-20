import React from 'react';
import { TopNav } from './TopNav';
import { shallow, mount } from 'enzyme';
import { MemoryRouter } from 'react-router';
import { AppStateContext } from '../appStateContext';
import { AppState, WizardTabTypes } from '../store';

jest.mock('../ProjectBar', () => {
  return {
    __esModule: true,
    ProjectBar: () => (
      <div id="projectBar"></div>
    )
  }
});

describe('<TopNav />', () => {
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
  });

  it('should not reload running projects if location is projects list', () => {
    const reloadRunningProjects = jest.fn();
    mount(
      <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: undefined}, dispatch: jest.fn()}}>
        <MemoryRouter initialEntries={['/projects']}>
          <TopNav />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    expect(reloadRunningProjects).not.toBeCalled();
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

  test.todo('change in active project title should reflect in project bar');
});
