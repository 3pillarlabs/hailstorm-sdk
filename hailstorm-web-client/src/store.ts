import { Project } from "./domain";
import {reducer as projectReducer} from './ProjectWorkspace/reducer';
import {reducer as runningProjectsReducer} from './TopNav/reducer';
import {reducer as newProjectWizardReducer} from './NewProjectWizard/reducer';
import { NewProjectWizardState, WizardTabTypes } from "./NewProjectWizard/domain";
import { RunningProjectsState } from "./TopNav/domain";
import { ActiveProjectState } from "./ProjectWorkspace/domain";
import { reducer as jmeterReducer } from './JMeterConfiguration/reducer';

export interface Action {
  type: string;
}

export type AppState =
  & RunningProjectsState
  & ActiveProjectState
  & NewProjectWizardState;

export const initialState: AppState = {
  runningProjects: [],
  activeProject: undefined
};

// export const initialState: AppState = {
//   runningProjects: [],
//   activeProject: {id: 8, code: 'sphynx', title: 'Sphynx', autoStop: false, running: false},
//   wizardState: {
//     activeTab: WizardTabTypes.JMeter,
//     done: {
//       [WizardTabTypes.Project]: true
//     }
//   }
// };

export const Injector: {
  [key: string]: (S: any | undefined, A: any) => any | undefined
} = {
  projectReducer,
  runningProjectsReducer,
  newProjectWizardReducer,
  jmeterReducer
};

export function rootReducer(state: AppState, action: any): AppState {
  let nextState: AppState = {
    ...state,
    activeProject: Injector.projectReducer(state.activeProject, action),
  };

  nextState = {
    ...nextState,
    runningProjects: Injector.runningProjectsReducer(nextState.runningProjects, action),
  }

  nextState = Injector.newProjectWizardReducer(nextState, action);

  nextState = Injector.jmeterReducer(nextState, action);

  return nextState;
}
