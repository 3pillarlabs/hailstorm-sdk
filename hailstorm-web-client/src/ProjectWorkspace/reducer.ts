import { Project } from "../domain";
import { ProjectWorkspaceActions, ProjectWorkspaceActionTypes } from "./actions";

export const reducer: (
  state: Project | undefined,
  action: ProjectWorkspaceActions
) => Project | undefined = (
  state,
  action
) => {
  switch (action.type) {
    case ProjectWorkspaceActionTypes.SetProject:
      return action.payload;

    case ProjectWorkspaceActionTypes.SetRunning:
      return {...state!, running: action.payload};

    case ProjectWorkspaceActionTypes.SetInterimState:
      return {...state!, interimState: action.payload};

    case ProjectWorkspaceActionTypes.UnsetInterimState:
      const next = {...state!};
      delete next.interimState;
      return next;

    case ProjectWorkspaceActionTypes.UnsetProject:
      return undefined;

    default:
      return state;
  }
};
