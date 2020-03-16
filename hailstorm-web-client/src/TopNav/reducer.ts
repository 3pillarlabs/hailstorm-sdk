import { ProjectBarActions, ProjectBarActionTypes } from "./actions";
import { Project } from "../domain";

export function reducer(state: Project[], action: ProjectBarActions): Project[] {
  let nextState: Project[];
  switch (action.type) {
    case ProjectBarActionTypes.SetRunningProjects:
      nextState = action.payload;
      break;

    case ProjectBarActionTypes.AddRunningProject:
      nextState = [...state, action.payload];
      break;

    case ProjectBarActionTypes.RemoveNotRunningProject:
      nextState = state.filter((p) => p.id !== action.payload.id);
      break;

    case ProjectBarActionTypes.ModifyRunningProject: {
      const match = state.find((p) => p.id === action.payload.projectId);
      if (match) {
        nextState = [...state.filter((p) => p.id !== match.id), {...match, ...action.payload.attrs}];
      } else {
        nextState = state;
      }

      break;
    }

    default:
      nextState = state;
      break;
  }

  return nextState;
}
