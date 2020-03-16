import { rootReducer, Injector } from "./store";
import { Project } from "./domain";
import { initialState } from "./store";
import { NewProjectWizardProgress, WizardTabTypes } from "./NewProjectWizard/domain";

describe('store', () => {
  describe('rootReduder', () => {
    beforeEach(() => {
      jest.resetModules();
    });

    it('should be defined', () => {
      expect(rootReducer).toBeDefined();
    });

    it('should join different state slices', async () => {
      const project: Project = { id: 1, code: 'a', title: 'A', running: false, autoStop: true };
      const projectReducer = jest.spyOn(Injector, "projectReducer").mockReturnValue(project);
      const runningProjectsReducer = jest.spyOn(Injector, "runningProjectsReducer").mockReturnValue([{
        id: 20, code: 'b', title: 'B', running: true, autoStop: false
      } as Project])

      const nextState = rootReducer(initialState, 'action');

      expect(projectReducer).toHaveBeenCalled();
      expect(nextState).toHaveProperty('activeProject');
      expect(nextState.activeProject!.code).toEqual(project.code);

      expect(runningProjectsReducer).toHaveBeenCalled();
      expect(nextState).toHaveProperty('runningProjects');
      expect(nextState.runningProjects.length).toEqual(1);
    });

    it('should combine states', () => {
      const activeProject: Project = { id: 1, code: 'a', title: 'A', running: false, autoStop: true };
      const wizardState: {
        activeProject: Project | undefined,
        wizardState: NewProjectWizardProgress
      } = {
        activeProject,
        wizardState: {
          activeTab: WizardTabTypes.Project,
          done: {}
        }
      };

      const newProjectWizardReducer = jest.spyOn(Injector, "newProjectWizardReducer").mockReturnValue(wizardState);
      const nextState = rootReducer(initialState, 'action');
      expect(newProjectWizardReducer).toBeCalled();
      expect(nextState).toHaveProperty('activeProject');
      expect(nextState.activeProject!.id).toEqual(activeProject.id);
      expect(nextState).toHaveProperty('wizardState.activeTab');
    });
  });
});
