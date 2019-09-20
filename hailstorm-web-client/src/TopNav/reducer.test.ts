import { reducer } from "./reducer";
import { SetRunningProjectsAction, AddRunningProjectAction, RemoveNotRunningProjectAction } from "./actions";
import { Project } from "../domain";

describe('reducer', () => {
  it('should set running projects', () => {
    const payload: Project[] = [
      {id: 1, code: 'a', title: 'A', running: true, autoStop: true}
    ];

    const nextState = reducer([], new SetRunningProjectsAction(payload));
    expect(nextState.length).toEqual(payload.length);
    expect(nextState[0]).toEqual(payload[0]);
  });

  it('should add a running project', () => {
    const payload: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: true};
    const nextState = reducer([], new AddRunningProjectAction(payload));
    expect(nextState.length).toEqual(1);
    expect(nextState[0]).toEqual(payload);
  });

  it('should remove a project that is not running', () => {
    const payload: Project = {id: 1, code: 'a', title: 'A', running: true, autoStop: true};
    const nextState = reducer([payload], new RemoveNotRunningProjectAction(payload));
    expect(nextState.length).toEqual(0);
  });
});
