import { act, fireEvent, render, wait } from '@testing-library/react';
import React from 'react';
import { DataCenterCluster } from '../domain';
import { FileServer, FileUploadSaga } from '../FileUpload/fileServer';
import { ClusterService } from '../services/ClusterService';
import { EditDataCenter } from './EditDataCenter';
import _ from 'lodash';
import { AppNotificationContextProps } from '../app-notifications';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider/AppNotificationProvider';

describe('<EditDataCenter.tsx />', () => {
  const dataCenterCluster: DataCenterCluster = {
    title: 'Sample DC',
    userName: 'joe',
    machines: ['192.168.0.10', '192.168.0.20'],
    sshIdentity: { name: 'fubar.pem', path: '1023/fubar.pem' },
    type: 'DataCenter',
    code: 'amazing-123',
    id: 123,
    sshPort: 8022
  };

  const activeProject = {
    id: 1,
    code: 'fubar',
    running: false,
    title: 'Test Project',
    clusters: [dataCenterCluster]
  };

  function withNotificationContext(content: JSX.Element) {
    const props: AppNotificationContextProps = {
      notifySuccess: jest.fn(),
      notifyInfo: jest.fn(),
      notifyWarning: jest.fn(),
      notifyError: jest.fn()
    };

    return (
      <AppNotificationProviderWithProps {...{...props}}>
        {content}
      </AppNotificationProviderWithProps>
    )
  }

  describe('when cluster is enabled', () => {
    describe('when no tests are running', () => {
      it('should show PEM file name and option to change/re-upload', () => {
        const {
          queryByDisplayValue
        } = render(
          withNotificationContext(
            <EditDataCenter
              cluster={{...dataCenterCluster}}
              {...{activeProject}}
              dispatch={jest.fn()}
            />
          )
        );

        const element = queryByDisplayValue(dataCenterCluster.sshIdentity.name);
        expect(element).not.toBeNull();
      });

      it('should be able to cancel the intent to modify the PEM file', async () => {
        const {
          queryByRole,
          findByRole,
          getByTestId
        } = render(
          withNotificationContext(
            <EditDataCenter
              cluster={{...dataCenterCluster}}
              {...{activeProject}}
              dispatch={jest.fn()}
            />
          )
        );

        const editIdentityTrigger = await findByRole("Edit SSH Identity");
        await wait(() => {
          fireEvent.click(editIdentityTrigger);
        });

        const fileUploadField = queryByRole("File Upload");
        expect(fileUploadField).not.toBeNull();
        expect(queryByRole("Edit SSH Identity")).toBeNull();

        const cancelTrigger = getByTestId("cancel-edit-ssh-identity");
        await wait(() => {
          fireEvent.click(cancelTrigger);
        });

        expect(queryByRole("Edit SSH Identity")).not.toBeNull();
      });

      it('should let all fields be updated', async () => {
        const {
          findByTestId,
          findByRole,
          findAllByTestId,
        } = render(
          withNotificationContext(
            <EditDataCenter
              cluster={{...dataCenterCluster}}
              {...{activeProject}}
              dispatch={jest.fn()}
            />
          )
        );

        const editIdentityTrigger = await findByRole("Edit SSH Identity");
        await wait(() => {
          fireEvent.click(editIdentityTrigger);
        });

        const titleField = await findByTestId("title");
        const userNameField = await findByTestId("userName");
        const fileUploadField = await findByRole("File Upload");
        const sshPortField = await findByTestId("sshPort");
        const machineFields = await findAllByTestId("dc-machine");
        const emptyMachineField = machineFields[dataCenterCluster.machines.length];
        const updateTrigger = await findByRole("Update Cluster");

        const file = new File(['12345'], "secure.pem", {type: "text/plain"});
        const saga = new FileUploadSaga(file, "https://upload.url");
        jest.spyOn(saga, 'begin').mockImplementation(() => {
          saga['promise'] = Promise.resolve({id: '1024/secure.pem'});
          return saga;
        });

        const fileServerSpy = jest.spyOn(FileServer, 'sendFile').mockReturnValue(saga);
        const updatedCluster: DataCenterCluster = {
          ...dataCenterCluster,
          title: "Sample DC Modified",
          userName: "joedimaggio",
          machines: ['192.168.0.10', '192.168.0.20', '192.168.0.30'],
          sshIdentity: { name: 'secure.pem', path: '1024/secure.pem' },
          sshPort: 22,
          type: 'DataCenter'
        }

        const updateResponse = Promise.resolve(updatedCluster);
        const updateApiSpy = jest.spyOn(ClusterService.prototype, "update").mockReturnValue(updateResponse);
        act(() => {
          fireEvent.change(titleField, {target: {value: updatedCluster.title}});
          fireEvent.change(userNameField, {target: {value: updatedCluster.userName}});
        });

        await wait(() => {
          fireEvent.change(fileUploadField, {target: {files: [file]}});
        });

        act(() => {
          fireEvent.change(emptyMachineField, {target: {value: updatedCluster.machines[2]}});
        });

        act(() => {
          fireEvent.change(sshPortField, {target: {value: updatedCluster.sshPort}});
        });

        act(() => {
          fireEvent.click(updateTrigger);
        });

        await updateResponse;
        await wait(() => {
          expect(fileServerSpy).toHaveBeenCalled();
          expect(updateApiSpy).toHaveBeenCalledWith(
            activeProject.id,
            dataCenterCluster.id,
            _.pick(updatedCluster, "title", "userName", "machines", "sshIdentity", "sshPort")
          );
        });
      });
    });
  });

  describe('when cluster is disabled', () => {
    it('should show the fields as readonly', () => {
      const {
        queryByTestId,
        queryByRole,
        getByDisplayValue,
        queryByDisplayValue
      } = render(
        withNotificationContext(
          <EditDataCenter
            cluster={{...dataCenterCluster, disabled: true}}
          />
        )
      );

      expect(queryByTestId("title")).toBeNull();
      expect(queryByTestId("userName")).toBeNull();
      expect(queryByRole("File Upload")).toBeNull();
      expect(getByDisplayValue(dataCenterCluster.machines[0]).hasAttribute("readonly")).toBe(true);
      expect(getByDisplayValue(dataCenterCluster.machines[1]).hasAttribute("readonly")).toBe(true);
      expect(queryByTestId("sshPort")).toBeNull();
      expect(queryByDisplayValue(dataCenterCluster.userName)).not.toBeNull();
      expect(queryByDisplayValue(dataCenterCluster.sshIdentity.name)).not.toBeNull();
      expect(queryByDisplayValue(dataCenterCluster.sshPort!.toString())).not.toBeNull();
    });
  });
});
