import { InterimProjectState, Project } from "../domain";
import { Action } from "../store";

export enum ProjectWorkspaceActionTypes {
  SetProject = '[ProjectWorkspace] SetProject',
  SetRunning = '[ProjectWorkspace] SetRunning',
  SetInterimState = '[ProjectWorkspace] SetInterimState',
  UnsetInterimState = '[ProjectWorkspace] UnsetInterimState',
  UnsetProject = '[ProjectWorkspace] UnsetProject',
  UpdateProject = '[ProjectWorkspace] UpdateProject',
}

export class SetProjectAction implements Action {
  readonly type = ProjectWorkspaceActionTypes.SetProject;
  constructor(public payload: Project) {};
}

export class SetRunningAction implements Action {
  readonly type = ProjectWorkspaceActionTypes.SetRunning;
  constructor(public payload: boolean) {}
}

export class SetInterimStateAction implements Action {
  readonly type = ProjectWorkspaceActionTypes.SetInterimState;
  constructor(public payload: InterimProjectState) {}
}

export class UnsetInterimStateAction implements Action {
  readonly type = ProjectWorkspaceActionTypes.UnsetInterimState;
}

export class UnsetProjectAction implements Action {
  readonly type = ProjectWorkspaceActionTypes.UnsetProject;
}

export class UpdateProjectAction implements Action {
  readonly type = ProjectWorkspaceActionTypes.UpdateProject;
  constructor(public payload: {[K in keyof Project]?: Project[K]}) {}
}

export type ProjectWorkspaceActions =
  | SetProjectAction
  | SetRunningAction
  | SetInterimStateAction
  | UnsetInterimStateAction
  | UnsetProjectAction
  | UpdateProjectAction;
