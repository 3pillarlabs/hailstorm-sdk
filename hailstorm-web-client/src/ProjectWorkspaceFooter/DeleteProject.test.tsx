import React from 'react';
import { ReactWrapper, mount } from 'enzyme';
import { Project, InterimProjectState } from '../domain';
import { DeleteProject } from './DeleteProject';
import { ProjectService } from "../services/ProjectService";
import { MemoryRouter } from 'react-router';
import { AppStateContext } from '../appStateContext';
import { act } from '@testing-library/react';

jest.mock('../Modal', () => ({
  __esModule: true,
  Modal: (props: React.PropsWithChildren<{isActive: boolean}>) => (
    props.isActive ? <div id="modal">{props.children}</div> : null
  )
}));

describe('<DeleteProject />', () => {
  const project: Project = {id: 1, code: 'a', title: 'A', running: false, autoStop: false};
  const dispatch = jest.fn();
  const buildComponent: (
    attrs: {[K in keyof Project]?: Project[K]}
  ) => JSX.Element = (
    attrs
  ) => (
    <AppStateContext.Provider value={{appState: {activeProject: {...project, ...attrs}, runningProjects: []}, dispatch}}>
      <MemoryRouter initialEntries={[`/projects/${project.id}`, '/projects']} initialIndex={0}>
        <DeleteProject />
      </MemoryRouter>
    </AppStateContext.Provider>
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
    act(() => {
      component.find('button').simulate('click');
    });
    component.update();
    expect(component).toContainExactlyOneMatchingElement('#modal');
  });

  it('should not take any action if modal is not confirmed', () => {
    component = mount(buildComponent({}));
    act(() => {
      component.find('button').simulate('click');
    });
    component.update();
    component.find('a.is-primary').simulate('click');
    expect(dispatch).not.toBeCalled();
  });

  it('should take delete action if modal is confirmed', (done) => {
    component = mount(buildComponent({}));
    act(() => {
      component.find('button').simulate('click');
    });
    component.update();
    const apiUpdateSpy = jest.spyOn(ProjectService.prototype, 'update').mockResolvedValue(undefined);
    const apiDeleteSpy = jest.spyOn(ProjectService.prototype, 'delete').mockResolvedValue(undefined);
    component.find('#modal button.is-danger').simulate('click');
    expect(dispatch).toBeCalled();
    expect(apiUpdateSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(apiDeleteSpy).toBeCalled();
    }, 0);
  });
});
