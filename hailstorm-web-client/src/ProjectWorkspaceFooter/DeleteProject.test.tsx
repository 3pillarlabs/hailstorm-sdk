import React from 'react';
import { ReactWrapper, mount } from 'enzyme';
import { ActiveProjectContext } from '../ProjectWorkspace/ProjectWorkspace';
import { Project, InterimProjectState } from '../domain';
import { DeleteProject } from './DeleteProject';
import { RunningProjectsContext } from '../RunningProjectsProvider/RunningProjectsProvider';
import { ProjectService } from '../api';
import { MemoryRouter } from 'react-router';

jest.mock('../Modal', () => ({
  __esModule: true,
  Modal: (props: React.PropsWithChildren<{isActive: boolean}>) => (
    props.isActive ? <div id="modal">{props.children}</div> : null
  )
}));

describe('<DeleteProject />', () => {
  const project: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
  const dispatch = jest.fn();
  const reloadRunningProjects = jest.fn();
  const buildComponent: (
    attrs: {[K in keyof Project]?: Project[K]}
  ) => JSX.Element = (
    attrs
  ) => (
    <RunningProjectsContext.Provider value={{runningProjects: [], reloadRunningProjects}}>
      <ActiveProjectContext.Provider value={{project: {...project, ...attrs}, dispatch}}>
        <MemoryRouter initialEntries={[`/projects/${project.id}`, '/projects']} initialIndex={0}>
          <DeleteProject />
        </MemoryRouter>
      </ActiveProjectContext.Provider>
    </RunningProjectsContext.Provider>
  )

  let component: ReactWrapper;

  afterEach(() => jest.resetAllMocks());

  it('should be disabled when the project is running', () => {
    component = mount(buildComponent({running: true}));
    expect(component.find('button')).toBeDisabled();
  });

  it('should be disabled when the project has interim state', () => {
    component = mount(buildComponent({interimState: InterimProjectState.STARTING}));
    expect(component.find('button')).toBeDisabled();
  });

  it('should invoke modal for confirmation', () => {
    component = mount(buildComponent({}));
    component.find('button').simulate('click');
    component.update();
    expect(component).toContainExactlyOneMatchingElement('#modal');
  });

  it('should not take any action if modal is not confirmed', () => {
    component = mount(buildComponent({}));
    component.find('button').simulate('click');
    component.update();
    component.find('a.is-primary').simulate('click');
    expect(dispatch).not.toBeCalled();
  });

  it('should take delete action if modal is confirmed', (done) => {
    component = mount(buildComponent({}));
    component.find('button').simulate('click');
    component.update();
    const apiUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(undefined);
    const apiDeleteSpy = jest.spyOn(ProjectService.prototype, 'delete').mockResolvedValue(undefined);
    component.find('#modal button.is-danger').simulate('click');
    expect(dispatch).toBeCalled();
    expect(apiUpdateSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(apiDeleteSpy).toBeCalled();
      expect(reloadRunningProjects).toBeCalled();
    }, 0);
  });
});
