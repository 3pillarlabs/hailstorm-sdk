import { reducer } from "./reducer";
import { ProjectSetupAction, ProjectSetupCancelAction, ConfirmProjectSetupCancelAction, StayInProjectSetupAction, CreateProjectAction, ClusterSetupCompletedAction, JMeterSetupCompletedAction, ActivateTabAction, ReviewCompletedAction, EditInProjectWizard, UnsetProjectAction, UpdateProjectTitleAction, SetProjectDeletedAction } from "./actions";
import { WizardTabTypes, NewProjectWizardProgress } from "./domain";
import { Project } from "../domain";
import { SaveClusterAction } from "../ClusterConfiguration/actions";

describe('reducer', () => {
  it('should define the function', () => {
    expect(reducer).toBeDefined();
  });

  it('should initiate the wizard', () => {
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: true, autoStop: true}
    }, new ProjectSetupAction());

    expect(nextState.activeProject).not.toBeDefined();
    expect(nextState).toHaveProperty('wizardState.activeTab');
    expect(nextState.wizardState!.activeTab).toEqual(WizardTabTypes.Project);
    expect(nextState).toHaveProperty('wizardState.done');
  });

  it('should exit the wizard', () => {
    const nextState = reducer({
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

  it('should update the active project title', () => {
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: true},
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {}
      }
    }, new UpdateProjectTitleAction('B'));

    expect(nextState.activeProject!.title).toEqual('B')
  });

  it('should flag the wizard if title is updated after review', () => {
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false
      },
      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true,
        }
      }
    }, new UpdateProjectTitleAction('B'));

    expect(nextState.wizardState!.modifiedAfterReview).toEqual(true);
  });

  it('should update JMeter setup', () => {
    const nextState = reducer({
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

  it('should edit JMeter configuration', () => {
    const activeProject: Project = {
      id: 1,
      code: 'a',
      title: 'A',
      running: false,
      jmeter: {
        files: [
          { id: 1, name: 'a.jmx', properties: new Map([["foo", "10"]]) },
          { id: 2, name: 'a.csv', dataFile: true }
        ]
      },
      clusters: [
        { id: 1, title: 'AWS us-east-1', type: 'AWS' },
        { id: 2, title: 'RAC 1', type: 'DataCenter' },
      ]
    };

    const nextState = reducer({activeProject}, new EditInProjectWizard({
      project: activeProject,
      activeTab: WizardTabTypes.JMeter
    }));

    expect(nextState.activeProject).toEqual(activeProject);
    expect(nextState.wizardState).toBeDefined();
    expect(nextState.wizardState).toEqual({
      activeTab: WizardTabTypes.JMeter,
      done: {
        [WizardTabTypes.Project]: true,
        [WizardTabTypes.JMeter]: true,
        [WizardTabTypes.Cluster]: true,
        [WizardTabTypes.Review]: true,
      },
      activeJMeterFile: { id: 1, name: 'a.jmx', properties: new Map([["foo", "10"]]) },
      activeCluster: { id: 1, title: 'AWS us-east-1', type: 'AWS' }
    } as NewProjectWizardProgress)
  });

  it('should unset the project if not editing in the wizard', () => {
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    }, new UnsetProjectAction());

    expect(nextState.activeProject).toBeUndefined();
  });

  it('should not unset the project if editing in the wizard', () => {
    const nextState = reducer({
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
        },
        confirmCancel: true
      },
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false}
    }, new UnsetProjectAction());

    expect(nextState.activeProject).toBeDefined();
  });

  it('should not prompt on canceling the wizard for a configured project without modifications', () => {
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        clusters: [
          { id: 23, type: 'DataCenter', title: 'RACK 1' }
        ],
        jmeter: {
          files: [
            { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) }
          ]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true
        },
        activeCluster: { id: 23, type: 'DataCenter', title: 'RACK 1' },
        activeJMeterFile: { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) }
      }
    }, new ConfirmProjectSetupCancelAction());

    expect(nextState.wizardState).toBeUndefined();
  });

  it('should confirm exiting the wizard when the project has been modified', () => {
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        clusters: [
          { id: 23, type: 'DataCenter', title: 'RACK 1' }
        ],
        jmeter: {
          files: [
            { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) },
            { id: 13, name: 'a.csv', dataFile: true}
          ]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true
        },
        activeCluster: { id: 23, type: 'DataCenter', title: 'RACK 1' },
        activeJMeterFile: { id: 12, name: 'a.jmx', properties: new Map([["foo", "1"]]) },
        modifiedAfterReview: true
      }
    }, new ConfirmProjectSetupCancelAction());

    expect(nextState.wizardState!.confirmCancel).toBeTruthy();
  });

  it('should edit an incomplete project from Project tab', () => {
    const project: Project = {
      id: 1,
      code: 'a',
      title: 'A',
      running: false,
      incomplete: true
    };

    const nextState = reducer({
      activeProject: undefined,
    }, new EditInProjectWizard({project}));

    expect(nextState.wizardState!.activeTab).toEqual(WizardTabTypes.Project);
    expect(nextState.activeProject).toEqual(project);
  });

  it('should mark a project complete after review', () => {
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        incomplete: true,
        jmeter: {
          files: [
            { id: 2, name: 'a.jmx', properties: new Map([["foo", "10"]]) }
          ]
        },
        clusters: [
          { id: 23, type: 'DataCenter', title: 'RACK 1' }
        ]
      },

      wizardState: {
        activeTab: WizardTabTypes.Review,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true,
          [WizardTabTypes.Cluster]: true,
          [WizardTabTypes.Review]: true
        },
        activeCluster: { id: 23, type: 'DataCenter', title: 'RACK 1' },
        activeJMeterFile: { id: 12, name: 'a.jmx', properties: new Map([["foo", "10"]]) }
      }
    }, new ReviewCompletedAction());

    expect(nextState.activeProject!.incomplete).toBeFalsy();
  });

  it ('should mark a project as destroyed', () => {
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        incomplete: true
      },

      wizardState: {
        activeTab: WizardTabTypes.Project,
        done: {
          [WizardTabTypes.Project]: true,
        }
      }
    }, new SetProjectDeletedAction());

    expect(nextState.activeProject!.destroyed).toBeTruthy();
  });

  it('should mark a tab for reload based on action payload', () => {
    const activeProject: Project = {
      id: 1,
      code: 'a',
      title: 'A',
      running: false,
      jmeter: {
        files: [
          { id: 1, name: 'a.jmx', properties: new Map([["foo", "10"]]) }        ]
      },
      clusters: [
        { id: 1, title: 'AWS us-east-1', type: 'AWS' }
      ]
    };

    const nextState = reducer({activeProject}, new EditInProjectWizard({
      project: activeProject,
      activeTab: WizardTabTypes.Cluster,
      reloadTab: true
    }));

    expect(nextState.wizardState!.reloadTab).toBe(true);
  });
});
