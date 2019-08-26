import React from 'react';
import { mount, ReactWrapper, shallow } from 'enzyme';
import { ProjectWorkspaceHeader } from './ProjectWorkspaceHeader';
import { act } from '@testing-library/react';
import { ProjectService } from '../api';
import { InterimProjectState } from '../domain';
import { AppStateContext } from '../appStateContext';

describe('<ProjectWorkspaceHeader />', () => {
  const project = { id: 1, code: 'a', title: 'Project Title', autoStop: true, running: false };
  let component: ReactWrapper | undefined = undefined;

  beforeEach(() => {
    act(() => {
      component = mount(
        <ProjectWorkspaceHeader {...{project}} />
      );
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should show project title by default', (done) => {
    setTimeout(() => {
      done();
      expect(component!.find('h2')).toHaveText(project.title);
    }, 0);
  });

  describe('when inline editing', () => {
    beforeEach(() => {
      component!.find('i[title="Edit"]').simulate('click');
    });

    it('should show text field on edit', () => {
      expect(component).toContainExactlyOneMatchingElement('input[type="text"]');
    });

    it('should show title on cancel', () => {
      component!.find('a').simulate('click');
      expect(component!.find('h2')).toHaveText(project.title);
    });

    it('should update title on submit', () => {
      project.running = true;
      const updateFnSpy = jest.spyOn(ProjectService.prototype, 'update').mockImplementation(jest.fn().mockResolvedValue(null));
      act(() => {
        component = mount(
          <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: undefined}, dispatch: jest.fn()}}>
            <ProjectWorkspaceHeader {...{project}} />
          </AppStateContext.Provider>
        );
      });

      component!.find('i[title="Edit"]').simulate('click');
      const updatedProjectTitle = `Updated ${project.title}`;
      const textInput: any = component!.find('input[type="text"]').instance(); // https://github.com/airbnb/enzyme/issues/76
      textInput.value = updatedProjectTitle;
      component!.find('form').simulate('submit');
      expect(updateFnSpy).toHaveBeenCalledWith(project.id, {title: updatedProjectTitle});
    });

    it('should not update if title is blank', () => {
      const updateFnSpy = jest.spyOn(ProjectService.prototype, 'update').mockImplementation(jest.fn().mockResolvedValue(null));
      act(() => {
        component = mount(
          <AppStateContext.Provider value={{appState: {runningProjects: [], activeProject: undefined}, dispatch: jest.fn()}}>
            <ProjectWorkspaceHeader {...{project}} />
          </AppStateContext.Provider>
        );
      });

      component!.find('i[title="Edit"]').simulate('click');
      const textInput: any = component!.find('input[type="text"]').instance(); // https://github.com/airbnb/enzyme/issues/76
      textInput.value = '';
      component!.find('form').simulate('submit');
      expect(component).toContainExactlyOneMatchingElement('p.help');
      expect(updateFnSpy).not.toHaveBeenCalled();
    });
  });

  describe('when transitioning project state', () => {
    it('should show no status text when project is not running', () => {
      const component = shallow(<ProjectWorkspaceHeader project={{id: 1, code: 'a', title: 'A', running: false, autoStop: true}} />);
      expect(component.find('.isStatus')).not.toExist();
    });

    [
      { match: "Starting", state: InterimProjectState.STARTING, verb: 'starting' },
      { match: "Stopping", state: InterimProjectState.STOPPING, verb: 'stopping' },
      { match: "Aborting", state: InterimProjectState.ABORTING, verb: 'aborting' },
    ].forEach(({match, state, verb}) => it(`should match "${match}..." status text when project is ${verb}`, () => {
      const component = shallow(
        <ProjectWorkspaceHeader
          project={{id: 1, code: 'a', title: 'A', running: false, autoStop: true, interimState: state}}
        />
      );
      expect(component.find('.isStatus').text()).toMatch(new RegExp(state, 'i'));
    }));

    it('should show "Running" status text when project is running', () => {
      const component = shallow(<ProjectWorkspaceHeader project={{id: 1, code: 'a', title: 'A', running: true, autoStop: true}} />);
      expect(component.find('.isStatus').text()).toMatch(new RegExp('running', 'i'));
    });
  });
});
