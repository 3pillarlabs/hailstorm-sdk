import { Project } from "./domain";

export interface Action {
  type: string;
}

export interface AppState {
  runningProjects: Project[];
  activeProject: Project | undefined;
}
