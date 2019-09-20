import { Action } from "../store";
import { Project } from "../domain";

/**
 * Action types that affect the ProjectBar
 */
export enum ProjectBarActionTypes {
  SetRunningProjects = '[ProjectBar] SetRunningProjects',
  AddRunningProject = '[ProjectBar] AddRunningProject',
  RemoveNotRunningProject = '[ProjectBar] RemoveNotRunningProject',
}

export class SetRunningProjectsAction implements Action {
  readonly type = ProjectBarActionTypes.SetRunningProjects;
  constructor(public payload: Project[]) {}
}

export class AddRunningProjectAction implements Action {
  readonly type = ProjectBarActionTypes.AddRunningProject;
  constructor(public payload: Project) {}
}

export class RemoveNotRunningProjectAction implements Action {
  readonly type = ProjectBarActionTypes.RemoveNotRunningProject;
  constructor(public payload: Project) {}
}

export type ProjectBarActions =
  | SetRunningProjectsAction
  | AddRunningProjectAction
  | RemoveNotRunningProjectAction;
