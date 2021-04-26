import { reducer } from './reducer';
import { WizardTabTypes, JMeterFileUploadState, NewProjectWizardState } from '../NewProjectWizard/domain';
import { AddJMeterFileAction, AbortJMeterFileUploadAction, CommitJMeterFileAction, MergeJMeterFileAction, SetJMeterConfigurationAction, SelectJMeterFileAction, RemoveJMeterFileAction, FileRemoveInProgressAction, DisableJMeterFileAction, EnableJMeterFileAction } from './actions';
import { JMeterFile, JMeter } from '../domain';

describe('reducer', () => {
  it('should indicate that file upload has started', () => {
    const payload = {name: 'a.jmx', dataFile: false};
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        }
      }
    }, new AddJMeterFileAction(payload));

    expect(nextState.wizardState!.activeJMeterFile).toBeDefined();
    expect(nextState.wizardState!.activeJMeterFile!).toEqual({...payload, uploadProgress: 0});
  });

  it('should indicate that a file upload failed', () => {
    const payload = { name: 'a.jmx', uploadError: 'Connection Lost' };
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: {
          name: 'a.jmx',
          dataFile: false,
          uploadProgress: 0
        }
      }
    }, new AbortJMeterFileUploadAction(payload));

    expect(nextState.wizardState!.activeJMeterFile!.uploadError).toEqual(payload.uploadError);
    expect(nextState.wizardState!.activeJMeterFile!.uploadProgress).toBeUndefined();
  });

  it('should show validation errors', () => {
    const payload: JMeterFileUploadState = {
      name: 'a.jmx',
      validationErrors: [{ type: 'error', message: 'Missing Simple DataWriter' }]
    };

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: {
          name: 'a.jmx',
          dataFile: false,
          uploadProgress: 0
        }
      }
    }, new AbortJMeterFileUploadAction(payload));

    expect(nextState.wizardState!.activeJMeterFile!.validationErrors).toEqual(payload.validationErrors);
  });

  it('should display a form to fill property values, when a test plan is validated successfully', () => {
    const entries: [string, string | undefined][] = [["foo", "yes"], ["baz", undefined]];
    const payload: JMeterFileUploadState = {
      name: 'a.jmx',
      properties: new Map<string, string | undefined>(entries)
    }

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: {
          name: 'a.jmx',
          dataFile: false,
          uploadProgress: 0
        }
      }
    }, new CommitJMeterFileAction(payload));

    expect(nextState.wizardState!.activeJMeterFile!.properties).toBeDefined();
    expect(Array.from(nextState.wizardState!.activeJMeterFile!.properties!.entries())).toEqual(entries);
    expect(nextState.wizardState!.activeJMeterFile!.uploadProgress).toEqual(100);
  });

  it('should set autoStop attribute of project after a test plan is validated', () => {
    const payload: JMeterFileUploadState & {autoStop?: boolean} = {
      name: 'a.jmx',
      properties: new Map<string, string | undefined>([["foo", "yes"], ["baz", undefined]]),
      autoStop: true
    };

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: {
          name: 'a.jmx',
          dataFile: false,
          uploadProgress: 0
        }
      }
    }, new CommitJMeterFileAction(payload));

    expect(nextState.activeProject!.autoStop).toEqual(true);
  });

  it('should set autoStop as false if it is true previously, but not reverse', () => {
    let state: NewProjectWizardState = {
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: true},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: {
          name: 'a.jmx',
          dataFile: false,
          uploadProgress: 0
        }
      }
    };

    const payload: JMeterFileUploadState & {autoStop?: boolean} = {
      name: 'a.jmx',
      properties: new Map<string, string | undefined>([["foo", "yes"], ["baz", undefined]]),
      autoStop: false
    };

    let nextState = reducer(state, new CommitJMeterFileAction(payload));
    expect(nextState.activeProject!.autoStop).toEqual(false);

    nextState = reducer(nextState, new CommitJMeterFileAction({...payload, autoStop: true}));
    expect(nextState.activeProject!.autoStop).toEqual(false);
  });

  it('should save the JMeter file with properties', () => {
    const payload: JMeterFile = {
      id: 10,
      name: 'a.jmx',
      dataFile: false,
      properties: new Map([["foo", "yes"], ["baz", "100"]])
    };

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: {
          name: 'a.jmx',
          dataFile: false,
          uploadProgress: 100,
          properties: new Map([["foo", "no"], ["baz", undefined]])
        }
      }
    }, new MergeJMeterFileAction(payload));

    expect(nextState.activeProject!.jmeter!.files.length).toEqual(1);
    expect(nextState.activeProject!.jmeter!.files[0].id).toEqual(payload.id);
    expect(nextState.wizardState!.activeJMeterFile!.properties).toEqual(payload.properties);
    expect(nextState.wizardState!.activeJMeterFile!.id).toEqual(payload.id);
  });

  it('should sort by active test plans on merge', () => {
    const payload = {
      id: 10,
      name: 'a.jmx',
      dataFile: false,
      properties: new Map([["foo", "yes"], ["baz", "100"]])
    };

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false, jmeter: {
        files: [
          {id: 99, name: 'a.csv', dataFile: true}
        ]
      }},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: {
          name: 'a.jmx',
          dataFile: false,
          uploadProgress: 100,
          properties: new Map([["foo", "no"], ["baz", undefined]])
        }
      }
    }, new MergeJMeterFileAction(payload));

    expect(nextState.activeProject!.jmeter!.files).toEqual([
      payload,
      {id: 99, name: 'a.csv', dataFile: true}
    ]);
  });

  it('should save modified properties', () => {
    const payload: JMeterFile = {
      id: 10,
      name: 'a.jmx',
      dataFile: false,
      properties: new Map([["foo", "yes"], ["baz", "200"]])
    };

    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        jmeter: {
          files: [
            {...payload, properties: new Map([["foo", "yes"], ["baz", "100"]])}
          ]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        },
        activeJMeterFile: { ...payload, properties: new Map([["foo", "yes"], ["baz", "100"]]) }
      }
    }, new MergeJMeterFileAction(payload));

    expect(nextState.activeProject!.jmeter!.files.length).toEqual(1);
    expect(nextState.activeProject!.jmeter!.files[0].properties).toEqual(payload.properties);
    expect(nextState.wizardState!.activeJMeterFile!.properties).toEqual(payload.properties);
  });

  it('should load JMeter configuration if not loaded', () => {
    const payload = {
      version: "3.2",
      files: [{ name: 'a.jmx', id: 10, properties: new Map([["foo", "10"]]) }]
    };

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false}
    }, new SetJMeterConfigurationAction(payload));

    expect(nextState.activeProject!.jmeter).toBeDefined();
    expect(nextState.activeProject!.jmeter).toEqual(payload);
  });

  it('it should sort the JMeter files with active test plans on loading of configuration', () => {
    const payload: JMeter = {
      files: [
        { name: 'b.csv', id: 103, dataFile: true, disabled: true },
        { name: 'a.jmx', id: 101, properties: new Map() },
        { name: 'a.csv', id: 103, dataFile: true },
        { name: 'b.jmx', id: 102, properties: new Map(), disabled: true },
      ]
    };

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false}
    }, new SetJMeterConfigurationAction(payload));

    expect(nextState.activeProject!.jmeter!.files).toEqual([
      { name: 'a.jmx', id: 101, properties: new Map() },
      { name: 'a.csv', id: 103, dataFile: true },
      { name: 'b.jmx', id: 102, properties: new Map(), disabled: true },
      { name: 'b.csv', id: 103, dataFile: true, disabled: true },
    ]);
  });

  it('should set first file as active on loading the configuration in the new project wizard', () => {
    const plan = { name: 'a.jmx', id: 10, properties: new Map([["foo", "10"]]) };
    const payload = {
      version: "3.2",
      files: [plan]
    };

    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true
        }
      }
    }, new SetJMeterConfigurationAction(payload));

    expect(nextState.wizardState!.activeJMeterFile).toEqual(plan);
  });

  it('should set active the selected plan or file', () => {
    const payload = { name: 'a.jmx', id: 10, properties: new Map([["foo", "10"]]) };
    const dataFile = { name: 'a.csv', dataFile: true, id: 19 };
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false, jmeter: { files: [payload, dataFile]}},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true,
        },
        activeJMeterFile: dataFile
      }
    }, new SelectJMeterFileAction(payload));

    expect(nextState.wizardState!.activeJMeterFile).toEqual(payload);
  });

  it('should remove active file and set next file as active', () => {
    const testPlan = { name: 'a.jmx', id: 10, properties: new Map([["foo", "10"]]) };
    const dataFile = { name: 'a.csv', id: 11, dataFile: true };
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false, jmeter: { files: [testPlan, dataFile]}},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true,
        },
        activeJMeterFile: testPlan
      }
    }, new RemoveJMeterFileAction(testPlan));

    expect(nextState.wizardState!.activeJMeterFile).toEqual(dataFile);
    expect(nextState.activeProject!.jmeter!.files.length).toEqual(1);
    expect(nextState.activeProject!.jmeter!.files[0].name).toEqual(dataFile.name);
  });

  it('should remove a file that is not added to the main list', () => {
    const testPlan = { name: 'a.jmx', id: 10, properties: new Map([["foo", undefined]]) };
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true,
        },
        activeJMeterFile: testPlan
      }
    }, new RemoveJMeterFileAction(testPlan));

    expect(nextState.wizardState!.activeJMeterFile).toBeUndefined();
    expect(nextState.activeProject!.jmeter).toBeUndefined();
  });

  it('should set active project as incomplete if there are no JMeter plans', () => {
    const testPlan = { name: 'a.jmx', id: 10, properties: new Map([["foo", "10"]]) };
    const dataFile = { name: 'a.csv', id: 11, dataFile: true };
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false, jmeter: { files: [testPlan, dataFile]}},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true,
        },
        activeJMeterFile: testPlan
      }
    }, new RemoveJMeterFileAction(testPlan));

    expect(nextState.activeProject!.incomplete).toBeTruthy();
  });

  it('should set active file to being removed', () => {
    const nextState = reducer({
      activeProject: {id: 1, code: 'a', title: 'A', running: false, autoStop: false},
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: {
          [WizardTabTypes.Project]: true,
        },
        activeJMeterFile: { name: 'a.jmx', id: 10, properties: new Map([["foo", undefined]]) }
      }
    }, new FileRemoveInProgressAction('a.jmx'));

    expect(nextState.wizardState!.activeJMeterFile!.removeInProgress).toEqual('a.jmx');
  });

  it('should disable a test plan', () => {
    const testPlanA = { name: 'a.jmx', id: 10, properties: new Map([["foo", "10"]]) };
    const dataFile = { name: 'a.csv', id: 11, dataFile: true };
    const testPlanB = { name: 'b.jmx', id: 12, properties: new Map([["foo", "10"]]) };
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        autoStop: false,
        jmeter: {
          files: [testPlanA, testPlanB, dataFile]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: { [WizardTabTypes.Project]: true},
        activeJMeterFile: { ...testPlanB }
      }
    }, new DisableJMeterFileAction(12));

    expect(nextState.activeProject!.jmeter!.files[1].disabled).toBe(true);
    expect(nextState.wizardState!.activeJMeterFile!.disabled).toBe(true);
  });

  it('should enable a test plan', () => {
    const testPlanB = { name: 'b.jmx', id: 12, properties: new Map([["foo", "10"]]), disabled: true };
    const nextState = reducer({
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        autoStop: false,
        jmeter: {
          files: [testPlanB]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: { [WizardTabTypes.Project]: true},
        activeJMeterFile: { ...testPlanB }
      }
    }, new EnableJMeterFileAction(12));

    expect(nextState.activeProject!.jmeter!.files[0].disabled).toBeFalsy();
    expect(nextState.wizardState!.activeJMeterFile!.disabled).toBeFalsy();
  });

  it('should mark project as incomplete if all test plans are disabled', () => {
    const testPlanA = { name: 'a.jmx', id: 10, properties: new Map([["foo", "10"]]) };
    const dataFile = { name: 'a.csv', id: 11, dataFile: true };
    const testPlanB = { name: 'b.jmx', id: 12, properties: new Map([["foo", "10"]]) };
    const state = {
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        running: false,
        autoStop: false,
        jmeter: {
          files: [testPlanA, testPlanB, dataFile]
        }
      },
      wizardState: {
        activeTab: WizardTabTypes.JMeter,
        done: { [WizardTabTypes.Project]: true},
        activeJMeterFile: { ...testPlanB }
      }
    };

    const state1 = reducer(state, new DisableJMeterFileAction(12));
    expect(state1.activeProject!.incomplete).toBeFalsy();

    const state2 = {...state1, wizardState: {...state1.wizardState!, activeJMeterFile: {...testPlanA}}};
    const state3 = reducer(state2, new DisableJMeterFileAction(10));
    expect(state3.activeProject!.incomplete).toBe(true);
  });
});
