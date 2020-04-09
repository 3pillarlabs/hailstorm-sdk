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
      nextState = {...state!, running: action.payload};
      break;

    case ProjectWorkspaceActionTypes.SetInterimState:
      nextState = {...state!, interimState: action.payload};
      break;

    case ProjectWorkspaceActionTypes.UnsetInterimState:
      nextState = {...state!};
      delete nextState.interimState;
      break;

    case ProjectWorkspaceActionTypes.UpdateProject:
      nextState = {...state!, ...action.payload};
      break;

    default:
      nextState = state;
      break;
  }

  return nextState;
};
