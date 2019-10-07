import React from 'react';
import { shallow, mount } from 'enzyme';
import { ProjectWorkspaceMain } from './ProjectWorkspaceMain';
import { AppStateContext } from '../appStateContext';
import { JMeterService } from '../api';
import { JMeter } from '../domain';

describe('<ProjectWorkspaceMain />', () => {
  it('should render without crashing', () => {
    shallow(<ProjectWorkspaceMain />);
  });

  it('should load JMeter configuration if not loaded', async () => {
    const jmeterPromise = Promise.resolve<JMeter>({files: [
      {id: 1, name: 'data.csv', dataFile: true}
    ]});

    jest.spyOn(JMeterService.prototype, "list").mockReturnValue(jmeterPromise);
    const dispatch = jest.fn();
    const component = mount(
      <AppStateContext.Provider
        value={{
          appState: {
            runningProjects: [],
            activeProject: {id: 1, code: 'a', title: 'A', running: false},
          },
          dispatch
        }}
      >
        <ProjectWorkspaceMain />
      </AppStateContext.Provider>
    );

    component.update();
    await jmeterPromise;
    expect(dispatch).toBeCalled();
  });
});
