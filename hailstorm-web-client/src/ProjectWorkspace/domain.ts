import { Project } from "../domain";

export interface ActiveProjectState {
  activeProject: Project | undefined;
}
