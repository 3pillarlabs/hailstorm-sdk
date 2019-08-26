import { ProjectBarActions, ProjectBarActionTypes } from "./actions";
import { Project } from "../domain";

export function reducer(state: Project[], action: ProjectBarActions): Project[] {
  switch (action.type) {
    case ProjectBarActionTypes.SetRunningProjects:
      return action.payload;

    case ProjectBarActionTypes.AddRunningProject:
      return [...state, action.payload];

    case ProjectBarActionTypes.RemoveNotRunningProject:
      return state.filter((p) => p.id !== action.payload.id);

    default:
      return state;
  }
}
