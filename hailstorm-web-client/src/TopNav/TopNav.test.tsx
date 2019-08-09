import React from 'react';
import { TopNav } from './TopNav';
import { shallow, mount } from 'enzyme';
import { MemoryRouter } from 'react-router';
import { RunningProjectsContext } from '../RunningProjectsProvider/RunningProjectsProvider';

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
    const reloadRunningProjects = jest.fn();
    mount(
      <RunningProjectsContext.Provider value={{runningProjects: [], reloadRunningProjects}}>
        <MemoryRouter initialEntries={['/projects/2']}>
          <TopNav />
        </MemoryRouter>
      </RunningProjectsContext.Provider>
    );

    expect(reloadRunningProjects).toBeCalled();
  });

  it('should not reload running projects if location is projects list', () => {
    const reloadRunningProjects = jest.fn();
    mount(
      <RunningProjectsContext.Provider value={{runningProjects: [], reloadRunningProjects}}>
        <MemoryRouter initialEntries={['/projects']}>
          <TopNav />
        </MemoryRouter>
      </RunningProjectsContext.Provider>
    );

    expect(reloadRunningProjects).not.toBeCalled();
  });
});
