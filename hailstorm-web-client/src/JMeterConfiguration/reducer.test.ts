import { reducer } from './reducer';
import { WizardTabTypes, JMeterFileUploadState } from '../NewProjectWizard/domain';
import { AddJMeterFileAction, AbortJMeterFileUploadAction, CommitJMeterFileAction, MergeJMeterFileAction, SetJMeterConfigurationAction } from './actions';
import { JMeterFile } from '../domain';

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
    expect(nextState.wizardState!.activeJMeterFile!).toEqual(payload);
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
});
