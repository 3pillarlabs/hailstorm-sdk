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

    case ProjectBarActionTypes.ModifyRunningProject: {
      const match = state.find((p) => p.id === action.payload.projectId);
      if (match) {
        return [...state.filter((p) => p.id !== match.id), {...match, ...action.payload.attrs}];
      } else {
        return state;
      }
    }

    default:
      return state;
  }
}
