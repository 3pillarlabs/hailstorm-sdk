import React, { useContext } from 'react';
import { shallow, mount, ReactWrapper } from 'enzyme';
import { ProjectWorkspace, ActiveProjectContext } from './ProjectWorkspace';
import { createHashHistory } from 'history';
import { Project, InterimProjectState } from '../domain';
import { Link, Route, MemoryRouter } from 'react-router-dom';
import { ProjectService } from '../api';
import { act } from '@testing-library/react';
import { SetRunningAction } from './actions';

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
      it('should show the project after component update', () => {
        const project: Project = { id: 1, code: 'a4', title: 'A4', running: false, autoStop: true };
        const component = mount(
          <ProjectWorkspace
            location={{hash: '', pathname: '', search: '', state: {project}}}
            history={createHashHistory()}
            match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
        );

        expect(component.find('div#projectWorkspaceHeader span#code')).toHaveText(project.code);
      });
    });

    describe('and different project is rendered before', () => {
      it('should show the project after component update', () => {
        const projects: Project[] = [
          { id: 1, code: 'a', title: 'A', running: false, autoStop: true },
          { id: 2, code: 'b', title: 'B', running: false, autoStop: true }
        ];

        let component = mount(
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
              <Route path="/projects/:id" component={ProjectWorkspace} />
            </div>
          </MemoryRouter>
        );

        component.find(`a.project-${projects[0].id}`).simulate('click', {button: 0});
        expect(component.find('div#projectWorkspaceHeader span#code')).toHaveText(projects[0].code);
        component.find(`a.project-${projects[1].id}`).simulate('click', {button: 0});
        expect(component.find('div#projectWorkspaceHeader span#code')).toHaveText(projects[1].code);
      });
    });
  });

  describe('when project is not passed through component props', () => {
    it('should show the project after component update', (done) => {
      const spy = jest
        .spyOn(ProjectService.prototype, "get")
        .mockImplementation(
          jest.fn().mockResolvedValue({
            id: 1,
            code: "a",
            title: "A",
            running: false,
            autoStop: true
          } as Project)
        );

      let component: ReactWrapper | null = null;
      act(() => {
        component = mount(
          <ProjectWorkspace
            location={{hash: '', pathname: '', search: '', state: null}}
            history={createHashHistory()}
            match={{isExact: true, params: {id: "1"}, path: '', url: ''}} />
        );
      });

      expect(spy).toHaveBeenCalled();
      setTimeout(() => {
        done();
        component!.update();
        console.debug(component!.html());
        expect(component!.find('div#projectWorkspaceHeader span#code')).toHaveText('a');
      }, 100);
    });
  });

  describe('setRunning', () => {
    it('should change project state', () => {
      const project: Project = { id: 1, code: 'a4', title: 'A4', running: false, autoStop: true };
      const Wrapper: React.FC = () => {
        const {dispatch} = useContext(ActiveProjectContext);
        return (
          <button id="setRunning" onClick={() => dispatch(new SetRunningAction(true))}></button>
        );
      };

      const component = mount(
        <ProjectWorkspace
          location={{hash: '', pathname: '', search: '', state: {project}}}
          history={createHashHistory()}
          match={{isExact: true, params: {id: "1"}, path: '', url: ''}}
        >
          <Wrapper />
        </ProjectWorkspace>
      );

      expect(component.find('div#projectWorkspaceHeader span#running').text()).toEqual('false');
      act(() => {
        component.find('button#setRunning').simulate('click');
      });

      component.update();
      console.debug(component.html());
      expect(component.find('div#projectWorkspaceHeader span#running').text()).toEqual('true');
    });
  });
});
