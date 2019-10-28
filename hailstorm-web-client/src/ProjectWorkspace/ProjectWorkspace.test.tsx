import React from 'react';
import { shallow, mount } from 'enzyme';
import { ProjectWorkspace } from './ProjectWorkspace';
import { createHashHistory } from 'history';
import { Project, InterimProjectState } from '../domain';
import { Link, Route, MemoryRouter, HashRouter } from 'react-router-dom';
import { ProjectService } from '../api';
import { act, render, fireEvent } from '@testing-library/react';
import { SetProjectAction } from './actions';
import { AppStateContext } from '../appStateContext';

jest.mock('../ProjectWorkspaceHeader', () => {
  return {
    ProjectWorkspaceHeader: () => (
      <div id="projectWorkspaceHeader">
        <span id="code"></span>
        <span id="running"></span>
      </div>
    ),
    __esModule: true
  };
});

jest.mock('../ProjectWorkspaceMain', () => {
  return {
    __esModule: true,
    ProjectWorkspaceMain: () => 'MockProjectWorkspaceMain '
  };
});

jest.mock('../ProjectWorkspaceLog', () => {
  return {
    __esModule: true,
    ProjectWorkspaceLog: () => 'MockProjectWorkspaceLog '
  };
});

jest.mock('../ProjectWorkspaceFooter', () => {
  return {
    __esModule: true,
    ProjectWorkspaceFooter: () => 'MockProjectWorkspaceFooter '
  };
});

jest.mock('../Modal', () => {
  return {
    __esModule: true,
    Modal: (props: React.PropsWithChildren<{isActive: boolean}>) => (
      props.isActive ? <div id="modal">{props.children}</div> : null
    )
  }
});

describe('<ProjectWorkspace />', () => {
  afterEach(() => {
    jest.resetAllMocks();
  });

  it('should show the loader initially', () => {
    const component = shallow(
      <ProjectWorkspace
        location={{hash: '', pathname: '', search: '', state: null}}
        history={createHashHistory()}
        match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
    );

    expect(component).toContainExactlyOneMatchingElement('Loader');
  });

  describe('when project is passed through component props', () => {
    describe('and no project is rendered before', () => {
      it('should show the project after component update', (done) => {
        const activeProject: Project = { id: 1, code: 'a4', title: 'A4', running: false, autoStop: true };
        const dispatch = jest.fn();
        mount(
          <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch}}>
            <MemoryRouter>
              <ProjectWorkspace
                location={{hash: '', pathname: '', search: '', state: {project: activeProject}}}
                history={createHashHistory()}
                match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
            </MemoryRouter>
          </AppStateContext.Provider>
        );

        setTimeout(() => {
          done();
          expect(dispatch).toBeCalled();
          expect(((dispatch.mock.calls[0][0]) as SetProjectAction).payload.code).toEqual(activeProject.code);
        }, 0);
      });
    });

    describe('and different project is rendered before', () => {
      it('should show the project after component update', async () => {
        const dispatch = jest.fn();
        const projects: Project[] = [
          { id: 1, code: 'a', title: 'A', running: false, autoStop: true, interimState: undefined },
          { id: 2, code: 'b', title: 'B', running: false, autoStop: true, interimState: undefined }
        ];

        const {findByText} = render(
          <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch}}>
            <HashRouter>
              {projects.map((project, index) => {
                return (
                  <Link
                    key={project.code}
                    to={{pathname: `/projects/${project.id}`, state: {project}}}
                    className={`project-${project.id}`}
                  >
                    {`Project ${index + 1}`}
                  </Link>
                )
              })}
              <div id="routingArea">
                <Route path="/projects/:id" render={(props) => (
                  <ProjectWorkspace {...props} />
                )} />
              </div>
            </HashRouter>
          </AppStateContext.Provider>
        );

        const projectLink_1 = await findByText('Project 1');
        act(() => {
          fireEvent.click(projectLink_1);
        });

        expect(((dispatch.mock.calls[0][0]) as SetProjectAction).payload.code).toEqual(projects[0].code);

        const projectLink_2 = await findByText('Project 2');
        act(() => {
          fireEvent.click(projectLink_2);
        });

        expect(((dispatch.mock.calls[1][0]) as SetProjectAction).payload.code).toEqual(projects[1].code);
      });
    });
  });

  describe('when project is not passed through component props', () => {
    it('should show the project after component update', (done) => {
      const project: Project = { id: 1, code: "a", title: "A", running: false, autoStop: true };
      const spy = jest.spyOn(ProjectService.prototype, "get").mockResolvedValue(project);
      const dispatch = jest.fn();

      act(() => {
        mount(
          <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch}}>
            <MemoryRouter>
              <ProjectWorkspace
                location={{hash: '', pathname: '', search: '', state: null}}
                history={createHashHistory()}
                match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
            </MemoryRouter>
          </AppStateContext.Provider>
        );
      });

      setTimeout(() => {
        expect(spy).toHaveBeenCalled();
        setTimeout(() => {
          done();
          expect(dispatch).toBeCalled();
          expect(((dispatch.mock.calls[0][0]) as SetProjectAction).payload.code).toEqual(project.code);
        }, 0);
      }, 0);
    });
  });

  it('should show modal warning when unmounted during in progress operations', async () => {
    const activeProject: Project = {
      id: 1,
      code: 'a4',
      title: 'A4',
      running: false,
      autoStop: true,
      interimState: InterimProjectState.STARTING
    };
    const dispatch = jest.fn();
    const {findByText} = render(
      <AppStateContext.Provider value={{appState: {activeProject, runningProjects: []}, dispatch}}>
        <HashRouter>
          <ProjectWorkspace
            location={{hash: '', pathname: `/projects/${activeProject.id}`, search: '', state: {project: activeProject}}}
            history={createHashHistory()}
            match={{isExact: true, params: {id: activeProject.id.toString()}, path: `/projects/${activeProject.id}`, url: ''}} />
          <Link to="/projects">Projects</Link>
        </HashRouter>
      </AppStateContext.Provider>
    );

    expect(dispatch).toBeCalled();
    const indexLink = await findByText(/projects/i);
    act(() => {
      fireEvent.click(indexLink);
    });

    const warningText = await findByText(/are you sure/i);
    expect(warningText).toBeTruthy();
  });

  it('should redirect to projects if id is not known', async () => {
    const rejection = Promise.reject('Not found');
    const spy = jest.spyOn(ProjectService.prototype, 'get').mockReturnValue(rejection);
    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch}}>
        <MemoryRouter>
          <ProjectWorkspace
            location={{hash: '', pathname: '', search: '', state: null}}
            history={createHashHistory()}
            match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
        </MemoryRouter>
      </AppStateContext.Provider>
    );

    return rejection.then(() => fail('should not reach here')).catch(() => {
      expect(spy).toBeCalled();
    })
  });
});
