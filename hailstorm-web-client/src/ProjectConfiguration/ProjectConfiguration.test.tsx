import React from 'react';
import { shallow } from 'enzyme';
import { ProjectConfiguration } from './ProjectConfiguration';
import { render, fireEvent, wait } from '@testing-library/react';
import { ProjectService } from '../api';
import { WizardTabTypes, AppState } from '../store';
import { AppStateContext } from '../appStateContext';
import { CreateProjectAction, ConfirmProjectSetupCancelAction } from '../NewProjectWizard/actions';

describe('<ProjectConfiguration />', () => {
  it('should render without crashing', () => {
    shallow(<ProjectConfiguration />);
  });

  it('should disable primary button initially', async () => {
    const {findByText} = render(
      <ProjectConfiguration />
    );

    const button = await findByText('Save & Next');
    expect(button.hasAttribute('disabled')).toBeTruthy();
  });

  it('should enable primary button on text input', async () => {
    const {findByPlaceholderText, findByText} = render(
      <ProjectConfiguration />
    );

    const textBox = await findByPlaceholderText('Project Title...');
    fireEvent.change(textBox, {target: {value: 'Some Title'}});
    const button = await findByText('Save & Next');
    expect(button.hasAttribute('disabled')).toBeFalsy();
  });

  it('should create new project on submit', async () => {
    jest.spyOn(ProjectService.prototype, 'create').mockResolvedValueOnce({
      id: 1, code: 'a', title: 'A', autoStop: false, running: true
    });

    const appState: AppState = {
      runningProjects: [],
      activeProject: undefined,
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      }
    }

    const dispatch = jest.fn();
    const {findByPlaceholderText, findByText} = render(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <ProjectConfiguration />
      </AppStateContext.Provider>
    );

    const textBox = await findByPlaceholderText('Project Title...');
    fireEvent.change(textBox, {target: {value: 'Some Title'}});
    const button = await findByText('Save & Next');
    fireEvent.click(button);
    await wait(() => expect(dispatch).toBeCalled());
    expect(dispatch.mock.calls[0][0]).toBeInstanceOf(CreateProjectAction);
  });

  it('should cancel', async () => {
    const appState: AppState = {
      runningProjects: [],
      activeProject: undefined,
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      }
    };

    const dispatch = jest.fn();
    const {findByText} = render(
      <AppStateContext.Provider value={{appState, dispatch}}>
        <ProjectConfiguration />
      </AppStateContext.Provider>
    );

    const cancel = await findByText('Cancel');
    fireEvent.click(cancel);
    await wait(() => expect(dispatch).toBeCalled());
    expect(dispatch.mock.calls[0][0]).toBeInstanceOf(ConfirmProjectSetupCancelAction);
  });
});
