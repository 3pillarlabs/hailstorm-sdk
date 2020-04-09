import { Action } from "../store";
import { Project } from "../domain";

/**
 * Action types that affect the ProjectBar
 */
export enum ProjectBarActionTypes {
  SetRunningProjects = '[ProjectBar] SetRunningProjects',
  AddRunningProject = '[ProjectBar] AddRunningProject',
  RemoveNotRunningProject = '[ProjectBar] RemoveNotRunningProject',
  ModifyRunningProject = '[ProjectBar] ModifyRunningProject',
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

export class ModifyRunningProjectAction implements Action {
  readonly type = ProjectBarActionTypes.ModifyRunningProject;
  constructor(public payload: {projectId: number, attrs: {[K in keyof Project]?: Project[K]}}) {}
}

export type ProjectBarActions =
  | SetRunningProjectsAction
  | AddRunningProjectAction
  | RemoveNotRunningProjectAction
  | ModifyRunningProjectAction;
