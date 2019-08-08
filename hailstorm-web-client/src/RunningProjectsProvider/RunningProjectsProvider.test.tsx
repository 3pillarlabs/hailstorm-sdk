import React, { useContext } from 'react';
import { mount } from 'enzyme';
import { RunningProjectsProvider, RunningProjectsContext } from './RunningProjectsProvider';
import { ProjectService } from '../api';
import { Project } from '../domain';
import { act } from '@testing-library/react';

describe('<RunningProjectsProvider />', () => {
  it('should reload running projects', (done) => {
    const ContainedComponent: React.FC = () => {
      const {runningProjects, reloadRunningProjects} = useContext(RunningProjectsContext);
      return (
        <div>
          <label>{runningProjects.length ? runningProjects[0].code : 'none'}</label>
          <button onClick={reloadRunningProjects}>Click Me</button>
        </div>
      );
    }

    const component = mount(
      <RunningProjectsProvider>
        <ContainedComponent />
      </RunningProjectsProvider>
    );

    expect(component.find('label').text()).toEqual('none');
    const apiSpy = jest.spyOn(ProjectService.prototype, 'list').mockResolvedValueOnce([
      { id: 1, autoStop: false, code: 'a', title: 'A', running: false },
      { id: 2, autoStop: false, code: 'b', title: 'B', running: true },
    ]);

    act(() => {
      component.find('button').simulate('click');
    });

    expect(apiSpy).toBeCalled();
    setTimeout(() => {
      done();
      expect(component.find('label').text()).toEqual('b');
    }, 0);
  });
});
