import { Project, InterimProjectState } from "../domain";
import { reducer } from "./reducer";
import { SetInterimStateAction, UnsetInterimStateAction, UpdateProjectAction, SetProjectAction, SetRunningAction, UnsetProjectAction } from "./actions";

describe("ProjectWorkspace reducer", () => {
  it("should set the interim state", () => {
    const initialProject: Project = {
      id: 1,
      code: "a4",
      title: "A4",
      running: false,
      autoStop: true
    };
    const nextProject = reducer(initialProject, new SetInterimStateAction(InterimProjectState.STARTING));
    expect(nextProject!.interimState).toEqual(InterimProjectState.STARTING);
  });

  it("should unset the interim state", () => {
    const initialProject: Project = {
      id: 1,
      code: "a4",
      title: "A4",
      running: false,
      autoStop: true,
      interimState: InterimProjectState.STARTING
    };
    const nextProject = reducer(initialProject, new UnsetInterimStateAction());
    expect(Object.keys(nextProject!)).not.toContain("interimState");
  });

  it('should update project', () => {
    const nextState = reducer({
      id: 1,
      code: 'a',
      title: 'B',
      running: false,
      autoStop: false
    }, new UpdateProjectAction({title: 'A'}));

    expect(nextState!.title).toEqual('A');
  });

  it('should set the project', () => {
    const nextState = reducer(undefined, new SetProjectAction({
      id: 1,
      code: 'a',
      title: 'A',
      running: false,
      autoStop: false
    }));

    expect(nextState!.title).toEqual('A');
  });

  it('should set the project running or stopped', () => {
    let nextState = reducer({
      id: 1,
      code: 'a',
      title: 'A',
      running: false,
      autoStop: false
    }, new SetRunningAction(true));

    expect(nextState!.running).toEqual(true);
    nextState = reducer(nextState, new SetRunningAction(false));
    expect(nextState!.running).toEqual(false);
  });

  it('should unset the project', () => {
    const nextState = reducer({
      id: 1,
      code: 'a',
      title: 'B',
      running: false,
      autoStop: false
    }, new UnsetProjectAction());

    expect(nextState).toBeUndefined();
  });
});
