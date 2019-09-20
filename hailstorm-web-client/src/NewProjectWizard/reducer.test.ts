import { reducer } from "./reducer";
import { ProjectSetupAction, ProjectSetupCancelAction, ConfirmProjectSetupCancelAction, StayInProjectSetupAction, CreateProjectAction, ClusterSetupCompletedAction, JMeterSetupCompletedAction, ActivateTabAction, ReviewCompletedAction } from "./actions";
import { WizardTabTypes } from "../store";
import { Project } from "../domain";

describe('reducer', () => {
  it('should define the function', () => {
    expect(reducer).toBeDefined();
  });

  it('should initiate the wizard', () => {
    const nextState = reducer({
      runningProjects: [],
      activeProject: {id: 1, code: 'a', title: 'A', running: true, autoStop: true}
    }, new ProjectSetupAction());

    expect(nextState.activeProject).not.toBeDefined();
    expect(nextState).toHaveProperty('wizardState.activeTab');
    expect(nextState.wizardState!.activeTab).toEqual(WizardTabTypes.Project);
    expect(nextState).toHaveProperty('wizardState.done');
  });

  it('should exit the wizard', () => {
    const nextState = reducer({
      runningProjects: [],
      activeProject: undefined,
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      }
    }, new ProjectSetupCancelAction());

    expect(nextState).not.toHaveProperty('wizardState');
  });

  it('should activate a tab', () => {
    const nextState = reducer({
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
        },
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}

    }, new ActivateTabAction(WizardTabTypes.JMeter));

    expect(nextState.wizardState!.activeTab).toEqual(WizardTabTypes.JMeter);
  });

  it('should update the active project', () => {
    const payload: Project = {id: 1, code: 'a', title: 'A', autoStop: false, running: true};
    const nextState = reducer({
      runningProjects: [],
      activeProject: undefined,
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      }
    }, new CreateProjectAction(payload));

    expect(nextState.activeProject).toBeDefined();
    expect(nextState.activeProject!.id).toEqual(payload.id);
    expect(nextState.wizardState!.activeTab).toEqual(WizardTabTypes.JMeter);
    expect(nextState.wizardState!.done).toHaveProperty(WizardTabTypes.Project);
  });

  it('should update JMeter setup', () => {
    const nextState = reducer({
      runningProjects: [],
      activeProject: {id: 1, code: 'a', title: 'A', autoStop: false, running: true},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        }
      }
    }, new JMeterSetupCompletedAction());

    expect(nextState.wizardState!.activeTab).toEqual(WizardTabTypes.Cluster);
    expect(nextState.wizardState!.done).toHaveProperty(WizardTabTypes.JMeter);
  });

  it('should update Cluster setup', () => {
    const nextState = reducer({
      runningProjects: [],
      activeProject: {id: 1, code: 'a', title: 'A', autoStop: false, running: true},
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true
        }
      }
    }, new ClusterSetupCompletedAction());

    expect(nextState.wizardState!.activeTab).toEqual(WizardTabTypes.Review);
    expect(nextState.wizardState!.done).toHaveProperty(WizardTabTypes.Cluster);
  });

  it('should complete review', () => {
    const nextState = reducer({
      runningProjects: [],
      activeProject: {id: 1, code: 'a', title: 'A', autoStop: false, running: true},
      wizardState: {
        activeTab: WizardTabTypes.Review,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true
        }
      }
    }, new ReviewCompletedAction());

    expect(nextState.wizardState).toBeUndefined();
  });

  it('should set up a cancel to be confirmed if there is an active project', () => {
    const nextState = reducer({
      runningProjects: [],
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: true},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        }
      }
    }, new ConfirmProjectSetupCancelAction());

    expect(nextState).toHaveProperty('wizardState.confirmCancel');
    expect(nextState.wizardState!.confirmCancel).toBeTruthy();
  });

  it('should exit the wizard on cancel if there is no active project', () => {
    const nextState = reducer({
      runningProjects: [],
      activeProject: undefined,
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      }
    }, new ConfirmProjectSetupCancelAction());

    expect(nextState.wizardState).toBeUndefined();
  });

  it('should remove confirmation of a cancel', () => {
    const nextState = reducer({
      runningProjects: [],
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
        },
        confirmCancel: true
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    }, new StayInProjectSetupAction());

    expect(nextState).not.toHaveProperty('confirmCancel');
  });
});
