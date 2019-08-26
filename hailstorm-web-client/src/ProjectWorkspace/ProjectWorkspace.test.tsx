import React, { useContext } from 'react';
import { shallow, mount, ReactWrapper } from 'enzyme';
import { ProjectWorkspace } from './ProjectWorkspace';
import { createHashHistory } from 'history';
import { Project } from '../domain';
import { Link, Route, MemoryRouter } from 'react-router-dom';
import { ProjectService } from '../api';
import { act } from '@testing-library/react';
import { SetRunningAction, SetProjectAction } from './actions';
import { AppStateContext } from '../appStateContext';

jest.mock('../ProjectWorkspaceHeader', () => {
  return {
    ProjectWorkspaceHeader: (props: {project: Project}) => (
      <div id="projectWorkspaceHeader">
        <span id="code">{props.project.code}</span>
        <span id="running">{props.project.running ? 'true' : 'false'}</span>
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
            <ProjectWorkspace
              location={{hash: '', pathname: '', search: '', state: {project: activeProject}}}
              history={createHashHistory()}
              match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
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
      it('should show the project after component update', (done) => {
        const dispatch = jest.fn();
        const projects: Project[] = [
          { id: 1, code: 'a', title: 'A', running: false, autoStop: true },
          { id: 2, code: 'b', title: 'B', running: false, autoStop: true }
        ];

        let component = mount(
          <AppStateContext.Provider value={{appState: {activeProject: undefined, runningProjects: []}, dispatch}}>
            <MemoryRouter>
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
            </MemoryRouter>
          </AppStateContext.Provider>
        );

        component.find(`a.project-${projects[0].id}`).simulate('click', {button: 0});
        setTimeout(() => {
          expect(((dispatch.mock.calls[0][0]) as SetProjectAction).payload.code).toEqual(projects[0].code);
          component.find(`a.project-${projects[1].id}`).simulate('click', {button: 0});
          setTimeout(() => {
            done();
            expect(((dispatch.mock.calls[1][0]) as SetProjectAction).payload.code).toEqual(projects[1].code);
          }, 0);
        }, 0);
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
            <ProjectWorkspace
              location={{hash: '', pathname: '', search: '', state: null}}
              history={createHashHistory()}
              match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
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
});
