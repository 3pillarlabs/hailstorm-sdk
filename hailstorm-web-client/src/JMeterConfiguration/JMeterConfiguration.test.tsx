import React from 'react';
import { mount } from "enzyme";
import { JMeterConfiguration } from "./JMeterConfiguration";
import { AppStateContext } from '../appStateContext';
import { AppState, Action } from '../store';
import { WizardTabTypes, JMeterFileUploadState } from '../NewProjectWizard/domain';
import { JMeterFile, Project, JMeter, ValidationNotice } from '../domain';
import { JMeterValidationService } from '../api';
import { JMeterService } from "../services/JMeterService";
import { SavedFile } from '../FileUpload/domain';
import { wait, fireEvent, waitForDomChange } from '@testing-library/dom';
import { FileServer } from '../FileUpload/fileServer';
import { render } from '@testing-library/react';

jest.mock('../FileUpload', () => ({
  __esModule: true,
  FileUpload: ({children}: React.PropsWithChildren<{
    onAccept: (file: File) => void;
    onFileUpload: (file: SavedFile) => void;
    onUploadError: (file: File, error: any) => void;
  }>) => (
    <div id="FileUpload">
      {children}
    </div>
  )
}));

jest.mock('../Modal', () => ({
  __esModule: true,
  Modal: ({
    isActive,
    children
  }: React.PropsWithChildren<{ isActive: boolean }>) => (
    isActive ? (<div id="modal">{children}</div>) : null
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

  function createComponent(attrs?: {plans?: JMeterFile[]}, incomplete: boolean = false) {
    let activeProject: Project = {id: 1, code: 'a', title: 'A', running: false};
    if (!incomplete) {
      activeProject.jmeter = attrs && attrs.plans ? {files: attrs.plans} : {files: []};
    }

    appState.activeProject = activeProject;
    return (
      <AppStateContext.Provider value={{appState, dispatch}}>
        <JMeterConfiguration />
      </AppStateContext.Provider>
    )
  }

  function mockFile(name: string): File {
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

  it('should render without crashing', async () => {
    const listPromise = Promise.resolve({ files: [] });
    const spy = jest.spyOn(JMeterService.prototype, "list").mockReturnValue(listPromise);
    const component = mount(createComponent(undefined, true));
    component.update();
    await listPromise;
    expect(spy).toHaveBeenCalled();
  });

  it('should display message when there are no test plans', async () => {
    const component = mount(createComponent());
    expect(component.text()).toMatch(/no test plans/);
    expect(component).not.toContainMatchingElement('ActiveFileDetail button[role="Remove File"]');
  });

  it('should show empty list of plans when there are no test plans', () => {
    const component = mount(createComponent()).find('JMeterConfiguration');
    expect(component).toContainExactlyOneMatchingElement('JMeterPlanList');
  });

  it('should disable Next button when there are no test plans', () => {
    const component = mount(createComponent());
    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    expect(nextButton).toBeDisabled();
  });

  it('should go back in wizard', () => {
    const component = mount(createComponent());
    const back = component.find('BackLink .button');
    back.simulate('click');
    expect(dispatch).toBeCalled();
    const action = dispatch.mock.calls[0][0] as Action;
    expect(action.payload).toEqual(WizardTabTypes.Project);
  });

  it('should indicate that file upload has started', () => {
    const component = mount(createComponent());
    const onAccept = component.find('FileUpload').prop('onAccept') as ((file: File) => void);
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

  it('should disable back and next button when a file is being uploaded', () => {
    appState.wizardState!.activeJMeterFile = {
      name: 'a.jmx',
      uploadProgress: 0
    };

    const component = mount(createComponent({plans: [
      { id: 10, name: 'b.jmx' }
    ]}));

    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    expect(nextButton).toBeDisabled();
    const backLink = component.find('a').findWhere((wrapper) => wrapper.text() === 'Back').at(0);
    expect(backLink).not.toExist();
  });

  it('should disable upload button when upload is in progress', () => {
    appState.wizardState!.activeJMeterFile = {
      name: 'a.jmx',
      uploadProgress: 0
    };

    const component = mount(createComponent({plans: [
      { id: 10, name: 'b.jmx' }
    ]}));

    const fileUpload = component.find('FileUpload');
    expect(fileUpload).toHaveProp('disabled', true);
    expect(fileUpload.find('button')).toBeDisabled();
  });

  it('should cancel an upload based on user action', () => {
    jest.useFakeTimers();
    try {
      appState.wizardState!.activeJMeterFile = {
        name: 'a.jmx',
        uploadProgress: 0
      };

      const component = mount(createComponent());
      expect(component.find('FileUpload')).toHaveProp('abort', false);
      const onAccept = component.find('FileUpload').prop('onAccept') as ((file: {name: string}) => void);
      onAccept({name: 'a.jmx'});
      jest.runAllTimers();
      component.update();
      component.find('JMeterFileMessage').find('button[role="Abort Upload"]').simulate('click');
      component.update();
      expect(component.find('FileUpload')).toHaveProp('abort', true);
    } finally {
      jest.useRealTimers();
    }
  });

  it('should indicate that a file upload failed', () => {
    const component = mount(createComponent());
    const onUploadError = component.find('FileUpload').prop('onUploadError') as ((file: File, error: any) => void);
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

  it('should enable back and next button when a file upload has failed', () => {
    appState.wizardState!.activeJMeterFile = {
      name: 'a.jmx',
      uploadProgress: undefined,
      uploadError: 'Server not available'
    };

    const component = mount(createComponent({plans: [
      { name: 'a.jmx', id: 100 }
    ]}));

    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    expect(nextButton).not.toBeDisabled();
    const backLink = component.find('a').findWhere((wrapper) => wrapper.text() === 'Back').at(0);
    expect(backLink).toExist();
  });

  it('should validate a successfully uploaded file', async () => {
    const validations = Promise.resolve<JMeterFileUploadState & {autoStop: boolean}>({
      name: "a.jmx",
      properties: new Map([["foo", undefined]]),
      autoStop: false
    });
    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: SavedFile) => void);
    onFileLoad({originalName: "a.jmx", id: "12345"});
    await validations;
    expect(dispatch).toHaveBeenCalled();
  });

  it('should show validation errors', async (done) => {
    const validation: ValidationNotice = {type: 'error', message: 'Missing DataWriter'};
    const validations = Promise.reject({validationErrors: [validation]});
    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: SavedFile) => void);
    onFileLoad({originalName: "a.jmx", id: "12345"});
    await wait();
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

  it('should enable back and next button when a file has failed validation', () => {
    appState.wizardState!.activeJMeterFile = {
      name: 'a.jmx',
      uploadProgress: 100,
      validationErrors: [{type: 'error', message: 'Missing DataWriter'}]
    };

    const component = mount(createComponent({plans: [
      { name: 'a.jmx', id: 100 }
    ]}));

    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    expect(nextButton).not.toBeDisabled();
    const backLink = component.find('a').findWhere((wrapper) => wrapper.text() === 'Back').at(0);
    expect(backLink).toExist();
  });

  it('should display a form to fill property values, when a test plan is validated successfully', async () => {
    const properties = new Map<string, any>([
      ["foo", undefined],
      ["bar", "x"],
      ["baz", 1]
    ]);

    const validations = Promise.resolve<JMeterFileUploadState & {autoStop: boolean}>({ name: "a.jmx", properties, autoStop: false });
    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: SavedFile) => void);
    onFileLoad({originalName: "a.jmx", id: "12345"});
    await validations;
    expect(dispatch).toBeCalled();
    appState.wizardState!.activeJMeterFile = { name: "a.jmx", properties, uploadProgress: 100 };
    component.setProps({value: {appState, dispatch}});
    component.update();
    const propertiesForm = component.find('JMeterPropertiesMap');
    expect(propertiesForm).toExist();
    expect(propertiesForm.prop('properties')).toEqual(properties);
  });

  it('should disable Next and Back buttons when there are unsaved properties', () => {
    const properties = new Map<string, any>([
      ["foo", undefined],
      ["bar", "x"],
      ["baz", "1"]
    ]);

    appState.wizardState!.activeJMeterFile = { name: "a.jmx", properties, uploadProgress: 100 };
    const component = mount(createComponent({plans: [
      { name: 'b.jmx', id: 100 }
    ]}));

    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    expect(nextButton).toBeDisabled();
    const backLink = component.find('a').findWhere((wrapper) => wrapper.text() === 'Back').at(0);
    expect(backLink).not.toExist();
  });

  it('should save the JMeter file with properties', async () => {
    const properties = new Map<string, any>([
      ["foo", undefined],
      ["bar", "x"],
      ["baz", 1]
    ]);

    const validations = Promise.resolve<JMeterFileUploadState & {autoStop: boolean}>({
      name: "a.jmx",
      properties,
      autoStop: false
    });

    jest.spyOn(JMeterValidationService.prototype, "create").mockReturnValue(validations);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: SavedFile) => void);
    onFileLoad({originalName: "a.jmx", id: "12345"});
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

  it('should show validation message if a field value is unset', async () => {
    const properties = new Map<string, any>([ ["bat", ""] ]);
    appState.wizardState!.activeJMeterFile = { id: 100, name: 'a.jmx', properties };
    const {findByTestId, findByText} = render(createComponent({plans: [{id: 100, name: 'a.jmx', properties}]}));
    const input = await findByTestId("bat");
    fireEvent.focus(input);
    fireEvent.change(input, {target: {value: ''}});
    fireEvent.blur(input);
    const errorMessage = await findByText(/blank/i);
    expect(errorMessage).toBeDefined();
  });

  it('should save a data file', async () => {
    const createdPromise = Promise.resolve({name: 'a.csv', dataFile: true, id: 23, path: "12345"});
    const spy = jest.spyOn(JMeterService.prototype, 'create').mockReturnValueOnce(createdPromise);
    const component = mount(createComponent());
    const onFileLoad = component.find('FileUpload').prop('onFileUpload') as ((file: SavedFile) => void);
    onFileLoad({originalName: "a.csv", id: "12345"});
    expect(dispatch).toBeCalled();
    const action = dispatch.mock.calls[0][0] as Action;
    expect(action.payload).toEqual({name: 'a.csv', dataFile: true, path: "12345"});
    expect(spy).toBeCalled();
    await createdPromise;
    expect(dispatch).toBeCalled();
    const nextAction = dispatch.mock.calls[1][0] as Action;
    expect(nextAction.payload).toEqual({name: 'a.csv', dataFile: true, id: 23, path: "12345"});
  });

  it('should enable Next and Back buttons when properties have been saved', () => {
    const properties = new Map<string, any>([
      ["foo", "bar"],
      ["bar", "x"],
      ["baz", "1"]
    ]);

    appState.wizardState!.activeJMeterFile = { name: "a.jmx", properties, uploadProgress: 100 };
    const component = mount(createComponent({plans: [
      { name: 'b.jmx', id: 100 }
    ]}));

    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    expect(nextButton).not.toBeDisabled();
    const backLink = component.find('a').findWhere((wrapper) => wrapper.text() === 'Back').at(0);
    expect(backLink).toExist();
  });

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

  it('should show properties for selected test plan', () => {
    const jmeterFile = {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])};
    const dataFile = {id: 99, name: 'a.csv', dataFile: true};
    appState.wizardState!.activeJMeterFile = dataFile;
    const component = mount(createComponent({plans: [jmeterFile, dataFile]}));
    const handleSelect = component.find('JMeterPlanList').prop("onSelect") as unknown as ((file: JMeterFile) => void);
    handleSelect(jmeterFile);
    appState.wizardState!.activeJMeterFile = jmeterFile;
    component.setProps({value: {appState, dispatch}});
    component.update();
    expect(component.find('input[name="foo"]')).toExist();
  });

  it('should show properties for selected data file', () => {
    const dataFile = {id: 99, name: 'a.csv', dataFile: true};
    appState.wizardState!.activeJMeterFile = dataFile;
    const component = mount(createComponent({plans: [dataFile]}));
    expect(component.find('ActiveFileDetail').text()).toMatch(/a\.csv/);
  });

  it('should confirm removal of a test plan or data file', () => {
    const jmeterFile = {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])};
    appState.wizardState!.activeJMeterFile = jmeterFile;
    const component = mount(createComponent({plans: [jmeterFile]}));
    component.find('ActiveFileDetail button[role="Remove File"]').simulate('click');
    expect(component).toContainExactlyOneMatchingElement('Modal');
  });

  it('should remove a test plan / data file from display if it is confirmed to be removed', async () => {
    const jmeterFile = {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])};
    const dataFile = {id: 99, name: 'a.csv', dataFile: true};
    appState.wizardState!.activeJMeterFile = jmeterFile;
    const component = mount(createComponent({plans: [jmeterFile, dataFile]}));
    component.find('ActiveFileDetail button[role="Remove File"]').simulate('click');
    const destroyFile = Promise.resolve();
    const destroySpy = jest.spyOn(JMeterService.prototype, "destroy").mockReturnValue(destroyFile);
    const removeFile = Promise.resolve();
    const removeSpy = jest.spyOn(FileServer, "removeFile").mockReturnValue(removeFile);
    component.find('Modal button').simulate('click');
    await destroyFile;
    await removeFile;
    expect(destroySpy).toBeCalled();
    expect(removeSpy).toBeCalled();
    expect(dispatch).toBeCalled();
    appState.wizardState!.activeJMeterFile = dataFile;
    appState.activeProject!.jmeter!.files = [dataFile];
    component.setProps({value: {appState, dispatch}});
    component.update();
    expect(component.find('ActiveFileDetail').text()).toMatch(/a\.csv/);
  });

  it('should request file server to remove an unmerged file', async () => {
    const jmeterFile = {name: 'a.jmx', properties: new Map([["foo", undefined]])};
    appState.wizardState!.activeJMeterFile = jmeterFile;
    const component = mount(createComponent());
    component.find('ActiveFileDetail button[role="Remove File"]').simulate('click');
    const removeFile = Promise.resolve();
    const removeSpy = jest.spyOn(FileServer, "removeFile").mockReturnValue(removeFile);
    component.find('Modal button').simulate('click');
    await removeFile;
    expect(removeSpy).toBeCalled();
  });

  it('should not remove the file if it is confirmed not to be removed', () => {
    const jmeterFile = {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])};
    const dataFile = {id: 99, name: 'a.csv', dataFile: true};
    appState.wizardState!.activeJMeterFile = jmeterFile;
    const component = mount(createComponent({plans: [jmeterFile, dataFile]}));
    component.find('ActiveFileDetail button[role="Remove File"]').simulate('click');
    component.find('Modal a').simulate('click');
    expect(dispatch).not.toBeCalled();
  });

  it('should set JMeter configuration as complete on click of Next button', () => {
    const jmeterFile = {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])};
    const dataFile = {id: 99, name: 'a.csv', dataFile: true};
    appState.wizardState!.activeJMeterFile = jmeterFile;
    const component = mount(createComponent({plans: [jmeterFile, dataFile]}));
    const nextButton = component.find('button').findWhere((wrapper) => wrapper.text() === 'Next').at(0);
    nextButton.simulate('click');
    expect(dispatch).toBeCalled();
  });

  it('should highlight active file in file list', () => {
    const jmeterFile = {id: 100, name: 'a.jmx', properties: new Map([["foo", "10"]])};
    const dataFile = {id: 99, name: 'a.csv', dataFile: true};
    appState.wizardState!.activeJMeterFile = dataFile;
    const component = mount(createComponent({plans: [jmeterFile, dataFile]}));
    const jmeterList = component.find('JMeterPlanList');
    expect(jmeterList).toHaveProp('activeFile', dataFile);
  });

  it('should show notification when removing a file', () => {
    const dataFile = { id: 100, name: 'a.csv', dataFile: true };
    appState.wizardState!.activeJMeterFile = dataFile;
    const component = mount(createComponent({plans: [dataFile]}));
    component.update();
    expect(component).not.toContainExactlyOneMatchingElement('#modal');
    component.find('button[role="Remove File"]').simulate('click');
    component.update();
    expect(component).toContainExactlyOneMatchingElement('#modal');
  });
});
