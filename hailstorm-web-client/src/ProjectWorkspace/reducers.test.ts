import { Project, InterimProjectState } from "../domain";
import { interimStateReducer } from "./reducers";

describe("interimStateReducer", () => {
  it("should set the interim state", () => {
    const initialProject: Project = {
      id: 1,
      code: "a4",
      title: "A4",
      running: false,
      autoStop: true
    };
    const nextProject = interimStateReducer(initialProject, {
      type: "set",
      payload: InterimProjectState.STARTING
    });
    expect(nextProject.interimState).toEqual(InterimProjectState.STARTING);
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
    const nextProject = interimStateReducer(initialProject, { type: "unset" });
    expect(Object.keys(nextProject)).not.toContain("interimState");
  });
});
