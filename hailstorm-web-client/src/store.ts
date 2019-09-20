import { Project } from "./domain";
import {reducer as projectReducer} from './ProjectWorkspace/reducer';
import {reducer as runningProjectsReducer} from './TopNav/reducer';
import {reducer as newProjectWizardReducer} from './NewProjectWizard/reducer';

export interface Action {
  type: string;
}

export enum WizardTabTypes {
  Project = 'Project',
  JMeter = 'JMeter',
  Cluster = 'Cluster',
  Review = 'Review'
}

type WizardTabTypesStrings = keyof typeof WizardTabTypes;

export interface NewProjectWizardProgress {
  activeTab: WizardTabTypes;
  done: {[k in WizardTabTypesStrings]?: boolean};
  confirmCancel?: boolean
}

export interface AppState {
  runningProjects: Project[];
  activeProject: Project | undefined;
  wizardState?: NewProjectWizardProgress;
}

export const initialState: AppState = {
  runningProjects: [],
  activeProject: undefined
};

export const Injector: {
  [key: string]: (S: any | undefined, A: any) => any | undefined
} = {
  projectReducer,
  runningProjectsReducer,
  newProjectWizardReducer
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

  return Injector.newProjectWizardReducer(nextState, action);
}
