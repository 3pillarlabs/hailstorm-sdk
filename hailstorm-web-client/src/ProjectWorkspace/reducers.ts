import { Project, InterimProjectState } from "../domain";

export const interimStateReducer: (
  state: Project,
  action: { type: 'set' | 'unset', payload?: InterimProjectState }
) => Project = (
  state,
  action
) => {
  switch (action.type) {
    case 'set':
      return {...state, interimState: action.payload};

    case 'unset':
      const next = {...state};
      delete next.interimState;
      return next;

    default:
      throw new Error();
  }
};
