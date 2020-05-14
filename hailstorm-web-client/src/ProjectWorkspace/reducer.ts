import { Project } from "../domain";
import { ProjectWorkspaceActions, ProjectWorkspaceActionTypes } from "./actions";

export const reducer: (
  state: Project | undefined,
  action: ProjectWorkspaceActions
) => Project | undefined = (
  state,
  action
) => {
  let nextState: Project | undefined = state;
  switch (action.type) {
    case ProjectWorkspaceActionTypes.SetProject:
      nextState = action.payload;
      break;

    case ProjectWorkspaceActionTypes.SetRunning:
      if (state) {
        nextState = {...state, running: action.payload};
      }

      break;

    case ProjectWorkspaceActionTypes.SetInterimState:
      if (state) {
        nextState = {...state, interimState: action.payload};
      }

      break;

    case ProjectWorkspaceActionTypes.UnsetInterimState:
      if (state) {
        nextState = {...state};
        delete nextState.interimState;
      }

      break;

    case ProjectWorkspaceActionTypes.UpdateProject:
      if (state) {
        nextState = {...state, ...action.payload};
        if (state.live && action.payload.live === false) {
          delete nextState.live;
        }
      }

      break;

    default:
      break;
  }

  return nextState;
};
