import { AppState } from './redux';
import {reducer as projectReducer} from './ProjectWorkspace/reducer';
import {reducer as runningProjectsReducer} from './TopNav/reducer';

export function rootReducer(state: AppState, action: any): AppState {
  const activeProject = projectReducer(state.activeProject, action);
  const runningProjects = runningProjectsReducer(state.runningProjects, action);
  return {...state, activeProject, runningProjects};
}
