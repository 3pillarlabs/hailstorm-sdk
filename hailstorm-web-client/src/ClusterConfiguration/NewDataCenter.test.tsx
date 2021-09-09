import { fireEvent, render, wait } from '@testing-library/react';
import { mount } from 'enzyme';
import React from 'react';
import { AppNotificationContextProps } from '../app-notifications';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider/AppNotificationProvider';
import { DataCenterCluster } from '../domain';
import { FileServer, FileUploadSaga } from '../FileUpload/fileServer';
import { WizardTabTypes } from '../NewProjectWizard/domain';
import { ClusterService } from '../services/ClusterService';
import { AppState } from '../store';
import { NewDataCenter } from './NewDataCenter';

describe('<NewDataCenter />', () => {
  let appState: AppState;
  const dispatch = jest.fn();

  beforeEach(() => {
    jest.resetAllMocks();
  });

  beforeEach(() => {
    appState = {
      activeProject: {
        id: 1,
        code: 'a',
        title: 'A',
        autoStop: true,
        running: false,
        jmeter: {
          files: [
            { id: 10, name: 'a.jmx', properties: new Map([["foo", "10"]]) },
            { id: 11, name: 'a.csv', dataFile: true }
          ]
        },
        clusters: []
      },

      runningProjects: [],

      wizardState: {
        activeTab: WizardTabTypes.Cluster,
        done: {
          [WizardTabTypes.Project]: true,
          [WizardTabTypes.JMeter]: true
        },
        activeJMeterFile: { id: 10, name: 'a.jmx', properties: new Map([["foo", "10"]]) },
        activeCluster: {title: '', type: 'DataCenter'}
      }
    }
  });

  function createComponent(notifiers?: {[K in keyof AppNotificationContextProps]: AppNotificationContextProps[K]}) {
    const props: AppNotificationContextProps = {
      notifySuccess: jest.fn(),
      notifyInfo: jest.fn(),
      notifyWarning: jest.fn(),
      notifyError: jest.fn(),
      ...notifiers
    };

    return (
      <AppNotificationProviderWithProps {...{...props}}>
        <NewDataCenter
          {...{dispatch}}
          activeProject={appState.activeProject!}
        />
      </AppNotificationProviderWithProps>
    )
  }

  it('should show form fields', () => {
    const component = mount(createComponent());
    expect(component.find('input[name="title"]')).toExist();
    expect(component.find('input[name="userName"]')).toExist();
    expect(component.find('input[name="sshPort"]')).toExist();
    expect(component.find('FileUpload[name="pemFile"]')).toExist();
    expect(component.find('MachineSet')).toExist();
  });

  it('should submit to create a cluster', async () => {
    const createdCluster: DataCenterCluster = {
      id: 42,
      title: 'RAC 1',
      code: 'rising-moon-346',
      type: 'DataCenter',
      userName: 'ubuntu',
      sshIdentity: {name: 'secure.pem'},
      machines: [ 'host-a', 'host-b' ],
      sshPort: 8022
    };

    const file = new File([], createdCluster.sshIdentity.name);
    const saga = new FileUploadSaga<string>(file, "https://upload.url");
    jest.spyOn(saga, 'begin').mockImplementation(() => {
      saga['promise'] = Promise.resolve("200 OK");
      return saga;
    });

    const fileServerSpy = jest.spyOn(FileServer, 'sendFile').mockReturnValue(saga);
    const createApiSpy = jest.spyOn(ClusterService.prototype, 'create').mockResolvedValueOnce(createdCluster);
    const component = mount(createComponent());
    component.find('input[name="title"]').simulate('change', {target: {value: createdCluster.title, name: 'title'}});
    component.find('input[name="userName"]').simulate('change', {target: {value: createdCluster.userName, name: 'userName'}});
    component.find('input[name="sshPort"]').simulate('change', {target: {value: createdCluster.sshPort, name: 'sshPort'}});
    const onFileAccept = component.find('FileUpload').prop('onAccept') as (file: File) => void;
    onFileAccept(file);
    const onMachinesChange = component.find('MachineSet').prop('onChange') as unknown as (machines: string[]) => void;
    onMachinesChange(createdCluster.machines);
    component.find('form').simulate('submit');
    await wait(() => {
      expect(createApiSpy).toBeCalled();
    });

    expect(fileServerSpy).toBeCalled();
    const clusterArg = {...createdCluster};
    delete clusterArg.id;
    delete clusterArg.code;
    expect(createApiSpy.mock.calls[0][1]).toEqual(clusterArg);
  });

  it('should validate inputs when form is submitted', async () => {
    const component = mount(createComponent());
    expect(component.find('button[type="submit"]')).toBeDisabled();
    component.find('input[name="title"]').simulate('change', {target: {value: 'foo', name: 'title'}});
    component.find('input[name="userName"]').simulate('change', {target: {value: 'baz', name: 'userName'}});
    component.find('input[name="sshPort"]').simulate('change', {target: {value: 8022, name: 'sshPort'}});

    const onFileAccept = component.find('FileUpload').prop('onAccept') as (file: File) => void;
    onFileAccept(new File([], 'secure.pem'));

    const onMachinesChange = component.find('MachineSet').prop('onChange') as unknown as (machines: string[]) => void;
    onMachinesChange([ 'host-a', 'host-b' ]);

    expect(component.find('button[type="submit"]')).not.toBeDisabled();
  });

  it('should show error messages on change when field validation fails', async () => {
    const {findByTestId, findByText} = render(createComponent());
    const expectError: (testId: string, value?: any) => void = async (testId, value) => {
      const input = await findByTestId(testId);
      fireEvent.focus(input);
      fireEvent.change(input, {target: {value: value || ''}});
      fireEvent.blur(input);
      const errorMessage = await findByText(new RegExp(`${testId}\.+blank`, 'i'));
      expect(errorMessage).toBeDefined();
    };

    setTimeout(() => {
      expectError('title');
      expectError('userName');
      expectError('sshPort', '-1');
    }, 10);
  });

  it('should display validation errors from api', async () => {
    const file = new File([], 'secure.pem');
    const saga = new FileUploadSaga(file, "https://upload.url");
    jest.spyOn(saga, 'begin').mockImplementation(() => {
      saga['promise'] = Promise.resolve("200 OK");
      return saga;
    });

    jest.spyOn(FileServer, 'sendFile').mockReturnValue(saga);
    const createApiSpy = jest.spyOn(ClusterService.prototype, 'create').mockImplementation(() => {
      return new Promise((_resolve, reject) => reject({
        validationErrors: {
          machines: {
            'host-a': 'not reachable',
            'host-b': 'unsupported JMeter version'
          },
          title: 'Title is already taken'
        }
      }));
    });

    const component = mount(createComponent());
    component.find('input[name="title"]').simulate('change', {target: {value: 'foo', name: 'title'}});
    component.find('input[name="userName"]').simulate('change', {target: {value: 'baz', name: 'userName'}});
    component.find('input[name="sshPort"]').simulate('change', {target: {value: 8022, name: 'sshPort'}});
    const onFileAccept = component.find('FileUpload').prop('onAccept') as (file: File) => void;
    onFileAccept(file);
    const onMachinesChange = component.find('MachineSet').prop('onChange') as unknown as (machines: string[]) => void;
    onMachinesChange([ 'host-a', 'host-b' ]);
    component.find('form').simulate('submit');
    await wait();
    expect(createApiSpy).toBeCalled();
  });

  it('should not upload PEM file immediately', () => {
    const component = mount(createComponent());
    expect(component.find('FileUpload')).toHaveProp('preventDefault', true);
  });

  it('should remove an incomplete active cluster', async () => {
    const {findByRole} = render(createComponent());
    const remove = await findByRole('Remove Cluster');
    fireEvent.click(remove);
    expect(dispatch).toBeCalled();
  });
});
