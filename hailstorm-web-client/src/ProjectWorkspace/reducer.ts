import { Project } from "../domain";
import { ProjectWorkspaceActions, ProjectWorkspaceActionTypes } from "./actions";

export const reducer: (
  state: Project | undefined,
  action: ProjectWorkspaceActions
) => Project | undefined = (
  state,
  action
) => {
  let nextState: Project | undefined;
  switch (action.type) {
    case ProjectWorkspaceActionTypes.SetProject:
      nextState = action.payload;
      break;

    case ProjectWorkspaceActionTypes.SetRunning:
      nextState = state ? {...state, running: action.payload} : state;
      break;

    case ProjectWorkspaceActionTypes.SetInterimState:
      nextState = state ? {...state, interimState: action.payload} : state;
      break;

    case ProjectWorkspaceActionTypes.UnsetInterimState:
      if (state) {
        nextState = {...state};
        delete nextState.interimState;
      } else {
        nextState = state;
      }

      break;

    case ProjectWorkspaceActionTypes.UpdateProject:
      if (state) {
        nextState = {...state, ...action.payload};
        if (state.live && action.payload.live === false) {
          delete nextState.live;
        }
      } else {
        nextState = state;
      }

      break;

    default:
      nextState = state;
      break;
  }

  return nextState;
};
