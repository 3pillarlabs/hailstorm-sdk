import { Project, InterimProjectState } from "../domain";
import { reducer } from "./reducers";
import { SetInterimStateAction, UnsetInterimStateAction } from "./actions";

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
});
