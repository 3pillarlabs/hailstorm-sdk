import React from 'react';
import { mount } from "enzyme";
import { JMeterConfiguration } from "./JMeterConfiguration";
import { AppStateContext } from '../appStateContext';
import { AppState } from '../store';
import { WizardTabTypes, JMeterFileUploadState } from '../NewProjectWizard/domain';
import { JMeterFile, Project, JMeter, ValidationNotice } from '../domain';
import { JMeterValidationService, JMeterService } from '../api';
import { LocalFile } from '../FileUpload/domain';
import { wait } from '@testing-library/dom';

jest.mock('../FileUpload', () => ({
  __esModule: true,
  FileUpload: (_props: {
    onAccept: (file: LocalFile) => void;
    onFileUpload: (file: LocalFile) => void;
    onUploadError: (file: LocalFile, error: any) => void;
  }) => (
    <div id="FileUpload"></div>
  )
}));

describe('<JMeterConfiguration />', () => {
  const dispatch = jest.fn();
  const appState: AppState = {
    runningProjects: [],
    activeProject: undefined,
    wizardState: {
      activeTab: WizardTabTypes.JMeter,
      done: {
        [WizardTabTypes.Project]: true
      }
    }
  };

  function createComponent(attrs?: {plans?: JMeterFile[]}) {
    let activeProject: Project = {id: 1, code: 'a', title: 'A', running: false};
    if (attrs && attrs.plans) {
      activeProject.jmeter = {files: attrs.plans};
    }

    appState.activeProject = activeProject;
    return (
      <AppStateContext.Provider value={{appState, dispatch}}>
        <JMeterConfiguration />
      </AppStateContext.Provider>
    )
  }

  function mockFile(name: string): LocalFile {
    return {
      name,
      type: 'text/xml',
      lastModified: 0,
      size: 100,
      slice: jest.fn()
    }
  }

  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    mount(createComponent());
  });

  it('should display message when there are no test plans', () => {
    const component = mount(createComponent());
    expect(component.text()).toMatch(/no test plans/);
  });

  it('should disable Next button when there are no test plans', () => {
    const component = mount(createComponent());
    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    expect(nextButton).toBeDisabled();
  });

  it('should indicate that file upload has started', () => {
    const component = mount(createComponent());
    const onAccept = component.find('FileUpload').prop('onAccept') as ((file: LocalFile) => void);
    onAccept(mockFile("a"));
    expect(dispatch).toHaveBeenCalled();
    appState.wizardState!.activeJMeterFile = {
      name: 'a.jmx',
      uploadProgress: 0
    };

    component.setProps({value: {appState, dispatch}});
    component.update();
    expect(component.text()).toMatch(/uploading a\.jmx/i);
  });

  test.todo('should disable back and next button when a file is being uploaded');

  it('should indicate that a file upload failed', () => {
    const component = mount(createComponent());
    const onUploadError = component.find('FileUpload').prop('onUploadError') as ((file: LocalFile, error: any) => void);
    const error = new Error('Server not available');
    onUploadError(mockFile("a"), error);
    appState.wizardState!.activeJMeterFile = {
      name: 'a.jmx',
      uploadProgress: undefined,
      uploadError: error
    };

    component.setProps({value: {appState, dispatch}});
    component.update();
    expect(component.text()).toMatch(/error uploading a\.jmx/i);
  });

  test.todo('should enable back and next button when a file upload has failed');

  it('should validate a successfully uploaded file', async () => {
    const validations = Promise.resolve<JMeterFileUploadState>({name: "a.jmx", properties: new Map([["foo", undefined]])});
    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: LocalFile) => void);
    onFileLoad(mockFile("a"));
    await validations;
    expect(dispatch).toHaveBeenCalled();
  });

  it('should show validation errors', (done) => {
    const validation: ValidationNotice = {type: 'error', message: 'Missing DataWriter'};
    const validations = Promise.reject({validationErrors: [validation]});
    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: LocalFile) => void);
    onFileLoad(mockFile("a"));
    validations
      .then(() => fail("Control should not reach here"))
      .catch(() => {
        done();
        expect(dispatch).toHaveBeenCalled();
        appState.wizardState!.activeJMeterFile = {
          name: 'a.jmx',
          uploadProgress: 100,
          validationErrors: [validation]
        };

        component.setProps({value: {appState, dispatch}});
        component.update();
        expect(component.text()).toMatch(/missing datawriter/i);
      });
  });

  test.todo('should enable back and next button when a file has failed validation');

  it('should display a form to fill property values, when a test plan is validated successfully', async () => {
    const properties = new Map<string, any>([
      ["foo", undefined],
      ["bar", "x"],
      ["baz", 1]
    ]);

    const validations = Promise.resolve<JMeterFileUploadState>({ name: "a.jmx", properties });
    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: LocalFile) => void);
    onFileLoad(mockFile("a"));
    await validations;
    expect(dispatch).toBeCalled();
    appState.wizardState!.activeJMeterFile = { name: "a.jmx", properties, uploadProgress: 100 };
    component.setProps({value: {appState, dispatch}});
    component.update();
    const propertiesForm = component.find('JMeterPropertiesMap');
    expect(propertiesForm).toExist();
    expect(propertiesForm.prop('properties')).toEqual(properties);
  });

  it('should save the JMeter file with properties', async () => {
    const properties = new Map<string, any>([
      ["foo", undefined],
      ["bar", "x"],
      ["baz", 1]
    ]);

    const validations = Promise.resolve<JMeterFileUploadState>({ name: "a.jmx", properties });
    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: LocalFile) => void);
    onFileLoad(mockFile("a"));
    await validations;
    appState.wizardState!.activeJMeterFile = { name: "a.jmx", properties };
    component.setProps({value: {appState, dispatch}});
    component.update();
    const propertiesForm = component.find('JMeterPropertiesMap');
    propertiesForm.find('input[name="foo"]').simulate('change', {target: {value: "yes", name: "foo"}});
    propertiesForm.find('input[name="baz"]').simulate('change', {target: {value: "3", name: "baz"}});
    const jmeterPlanPromise: Promise<JMeterFile> = Promise.resolve<JMeterFile>({
      id: 1,
      properties: new Map([["foo", "yes"], ["baz", "3"], ["bar", "x"]]),
      name: "a.jmx"
    });

    const jmeterServiceSpy = jest.spyOn(JMeterService.prototype, "create").mockReturnValue(jmeterPlanPromise);
    propertiesForm.find('form').simulate('submit');
    await jmeterPlanPromise;
    await wait(() => {
      expect(jmeterServiceSpy).toBeCalled();
    });
  });

  it('should save modified properties', async () => {
    const properties = new Map<string, any>([
      ["foo", "yes"],
      ["bar", "x"],
      ["baz", 1]
    ]);

    appState.wizardState!.activeJMeterFile = { id: 100, name: 'a.jmx', properties };
    const updates = Promise.resolve({
      ...appState.wizardState!.activeJMeterFile,
      properties: new Map([
        ["foo", "yes"],
        ["bar", "x"],
        ["baz", "3"]
      ])
    });

    const updateServiceSpy = jest.spyOn(JMeterService.prototype, "update").mockReturnValue(updates);
    const component = mount(createComponent({plans: [{id: 100, name: 'a.jmx', properties}]}));
    const propertiesForm = component.find('JMeterPropertiesMap');
    propertiesForm.find('input[name="baz"]').simulate('change', {target: {value: "3", name: "baz"}});
    propertiesForm.find('form').simulate('submit');
    await updates;
    await wait(() => {
      expect(updateServiceSpy).toBeCalled();
    });

    expect(dispatch).toBeCalled();
  });

  test.todo('should enable Next and Back buttons when properties have been saved');

  it('should show existing test plans', () => {
    const mockPlan: JMeterFile = { id: 1, properties: new Map(), name: 'a.jmx' };
    const component = mount(createComponent({plans: [mockPlan]}));
    const planList = component.find('JMeterPlanList');
    const jmeterProp = planList.prop('jmeter') as JMeter;
    const plans = jmeterProp.files;
    expect(plans.length).toEqual(1);
    expect(plans[0].name).toEqual(mockPlan.name);
  });

  it('should enable Next button when at least one test plan is uploaded', () => {
    const mockPlan = { id: 1, properties: new Map(), name: 'a.jmx' };
    const component = mount(createComponent({plans: [mockPlan]}));
    expect(component.find('button').findWhere((wrapper) => wrapper.text() === 'Next')).not.toBeDisabled();
  });

  it('should not enable Next button if only data files are uploaded', () => {
    const file = { id: 1, properties: new Map(), name: 'a.csv', dataFile: true };
    const component = mount(createComponent({plans: [file]}));
    expect(component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0)).toBeDisabled();
  });

  test.todo('should confirm removal of a test plan or data file');

  test.todo('should remove a test plan / data file from display if it is confirmed to be removed');

  test.todo('should not remove the file if it is confirmed not to be removed');
});
