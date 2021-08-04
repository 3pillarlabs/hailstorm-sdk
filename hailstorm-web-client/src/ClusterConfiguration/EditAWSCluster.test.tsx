import React from 'react';
import { act, fireEvent, render, wait } from '@testing-library/react';
import { AmazonCluster, Project } from '../domain';
import { EditAWSCluster } from './EditAWSCluster';
import { UpdateClusterAction } from './actions';
import { ClusterService } from '../services/ClusterService';
import { AppNotificationContextProps } from '../app-notifications';
import { AppNotificationProviderWithProps } from '../AppNotificationProvider/AppNotificationProvider';
import { AWSInstanceChoiceOption } from './domain';
import { AWSEC2PricingService } from '../services/AWSEC2PricingService';

jest.mock('../Modal', () => ({
  __esModule: true,
  Modal: ({isActive, children}: React.PropsWithChildren<{isActive: boolean}>) => (
    isActive ? <div id="modal">{children}</div> : null
  )
}));

describe('<EditAWSCluster />', () => {
  const cluster: AmazonCluster = {
    id: 123,
    accessKey: 'A',
    secretKey: 's',
    instanceType: 't3a.large',
    maxThreadsByInstance: 100,
    region: 'us-east-1',
    title: 'AWS us-east-1',
    type: 'AWS'
  };

  const activeProject: Project = {
    id: 1,
    code: 'abc',
    running: false,
    title: 'ABC'
  };

  const dispatch = jest.fn();
  let fetchPricing: Promise<AWSInstanceChoiceOption[]>;

  function withNotificationContext(
    component: JSX.Element,
    notifiers?: {[K in keyof AppNotificationContextProps]: AppNotificationContextProps[K]}
  ) {
    const props: AppNotificationContextProps = {
      notifySuccess: jest.fn(),
      notifyInfo: jest.fn(),
      notifyWarning: jest.fn(),
      notifyError: jest.fn(),
      ...notifiers
    };

    return (
      <AppNotificationProviderWithProps {...{...props}}>
        {component}
      </AppNotificationProviderWithProps>
    );
  }

  beforeEach(() => {
    jest.resetAllMocks();
  });

  beforeEach(() => {
    fetchPricing = Promise.resolve([
      new AWSInstanceChoiceOption({
        instanceType: 'm3a.small', numInstances: 1, maxThreadsByInstance: 500, hourlyCostByInstance: 0.092
      }),
      new AWSInstanceChoiceOption({
        instanceType: 'm3a.large', numInstances: 1, maxThreadsByInstance: 5000, hourlyCostByInstance: 1.084
      })
    ]);

    jest.spyOn(AWSEC2PricingService.prototype, 'list').mockReturnValue(fetchPricing);
  });

  describe('with an enabled cluster', () => {
    it('should let the user update all fields except region', async () => {
      const projectFixture = {...activeProject};
      delete projectFixture.live;
      const updatedAttributes: {[K in keyof AmazonCluster]?: AmazonCluster[K]} = {
        accessKey: 'Aa',
        secretKey: 'ss',
        instanceType: 'm3a.large',
        maxThreadsByInstance: 200,
        vpcSubnetId: 'vpc-123',
        baseAMI: 'ami-123'
      };

      const clusterFixture = {...cluster, region: 'eu-west-3', baseAMI: 'ami-xyz'};
      const promise: Promise<AmazonCluster> = Promise.resolve({...clusterFixture, ...updatedAttributes});
      const apiSpy = jest.spyOn(ClusterService.prototype, 'update').mockReturnValue(promise);
      const { getByRole, getByDisplayValue, queryByTestId, queryByRole, getByText, findByTestId, findByText } = render(
        withNotificationContext(<EditAWSCluster {...{cluster: clusterFixture, activeProject: projectFixture, dispatch}} />)
      );

      await fetchPricing;
      const accessKeyField = queryByTestId('AWS Access Key');
      expect(accessKeyField).not.toBeNull();
      const secretKeyField = queryByTestId('AWS Secret Key');
      expect(secretKeyField).not.toBeNull();
      const vpcSubnetField = queryByTestId('VPC Subnet');
      expect(vpcSubnetField).not.toBeNull();
      expect(getByDisplayValue(clusterFixture.region).hasAttribute('readonly')).toBe(true);
      expect(queryByRole('EditRegion')).toBeNull();
      const baseAmiField = queryByTestId('Base AMI');
      expect(baseAmiField).not.toBeNull();

      act(() => {
        fireEvent.change(accessKeyField!, {target: {value: updatedAttributes.accessKey}});
        fireEvent.change(secretKeyField!, {target: {value: updatedAttributes.secretKey}});
        fireEvent.change(vpcSubnetField!, {target: {value: updatedAttributes.vpcSubnetId}});
        fireEvent.change(baseAmiField!, {target: {value: updatedAttributes.baseAMI}});
      });

      act(() => {
        fireEvent.click(getByText(/AWS Instance Type by Usage/i));
      });

      const confirmYes = await findByText(/Yes/i);
      fireEvent.click(confirmYes);
      const maxPlannedUsersField = await findByTestId('MaxPlannedUsers');
      const maxUsersByInstanceField = await findByTestId('Max. Users / Instance');

      act(() => {
        fireEvent.change(maxPlannedUsersField!, {target: {value: updatedAttributes.maxThreadsByInstance! * 10}});
      });

      act(() => {
        fireEvent.change(maxUsersByInstanceField!, {target: {value: updatedAttributes.maxThreadsByInstance}});
      });

      act(() => {
        const updateTrigger = getByRole('Update Cluster');
        fireEvent.click(updateTrigger);
      });

      await promise;
      await wait(async () => {
        expect(apiSpy).toHaveBeenCalledWith(1, 123, updatedAttributes);
        expect(dispatch).toHaveBeenCalled();
        const action = dispatch.mock.calls[0][0];
        expect(action).toBeInstanceOf(UpdateClusterAction);
      }, {timeout: 1000});
    });

    it('should not let the user edit base AMI for a supported region', () => {
      const { queryByTestId } = render(
        withNotificationContext(<EditAWSCluster {...{cluster, activeProject, dispatch}} />)
      );

      const baseAmiField = queryByTestId('Base AMI');
      expect(baseAmiField).toBeNull();
    });

    describe('when the cluster is live', () => {
      let projectFixture: Project;
      beforeEach(() => {
        projectFixture = {...activeProject, live: true};
      });

      it('should let the user edit only Max users per instance', () => {
        const clusterFixture = {...cluster, region: 'eu-west-3', baseAMI: 'ami-xyz', vpcSubnetId: 'vpc-123'};
        const { queryByTestId, getByDisplayValue, queryByDisplayValue, queryByRole, debug } = render(
          withNotificationContext(<EditAWSCluster {...{cluster: clusterFixture, activeProject: projectFixture, dispatch}} />)
        );

        expect(getByDisplayValue(clusterFixture.accessKey).hasAttribute("readonly")).toBe(true);
        expect(queryByDisplayValue(clusterFixture.secretKey)).toBeNull();
        expect(getByDisplayValue(clusterFixture.vpcSubnetId!).hasAttribute("readonly")).toBe(true);
        expect(getByDisplayValue(clusterFixture.region).hasAttribute("readonly")).toBe(true);
        expect(queryByRole('EditRegion')).toBeNull();
        expect(getByDisplayValue(clusterFixture.baseAMI!).hasAttribute("readonly")).toBe(true);
        expect(queryByTestId('MaxPlannedUsers')).toBeNull();
        expect(queryByTestId('Max. Users / Instance')).not.toBeNull();
      });

      it('should update Max users per instance', async () => {
        const promise: Promise<AmazonCluster> = Promise.resolve({...cluster, maxThreadsByInstance: 200});
        const apiSpy = jest.spyOn(ClusterService.prototype, 'update').mockReturnValue(promise);
        const { findByRole, findByTestId } = render(
          withNotificationContext(<EditAWSCluster {...{cluster, activeProject: projectFixture, dispatch}} />)
        );

        const input = await findByTestId('Max. Users / Instance');
        act(() => {
          fireEvent.focus(input);
          fireEvent.change(input, {target: {value: '200'}});
          fireEvent.blur(input);
        });

        const updateTrigger = await findByRole('Update Cluster');
        act(() => {
          fireEvent.click(updateTrigger);
        });

        await wait(async () => {
          await promise;
          expect(apiSpy).toHaveBeenCalledWith(1, 123, {maxThreadsByInstance: '200'});
          expect(dispatch).toHaveBeenCalled();
          const action = dispatch.mock.calls[0][0];
          expect(action).toBeInstanceOf(UpdateClusterAction);
        }, {timeout: 1000});
      });
    });
  });

  describe('with a disabled cluster', () => {
    it('should not have update trigger', async () => {
      const { queryAllByRole, queryAllByTestId } = render(
        <EditAWSCluster
          {...{cluster: {...cluster, disabled: true}, activeProject, dispatch}}
        />
      );

      const inputs = queryAllByTestId('Max. Users / Instance');
      expect(inputs.length).toBe(0);

      const triggers = queryAllByRole('Update Cluster');
      expect(triggers.length).toBe(0);
    });

    it('should not let user edit any field', () => {
      const clusterFixture: AmazonCluster = {
        ...cluster,
        region: 'eu-west-3', baseAMI: 'ami-xyz', disabled: true, vpcSubnetId: 'vpc-123'
      };

      const { getByDisplayValue, queryByDisplayValue, queryByRole, queryByTestId } = render(
        withNotificationContext(<EditAWSCluster {...{cluster: clusterFixture, activeProject, dispatch}} />)
      );

      expect(getByDisplayValue(clusterFixture.accessKey).hasAttribute("readonly")).toBe(true);
      expect(queryByDisplayValue(clusterFixture.secretKey)).toBeNull();
      expect(getByDisplayValue(clusterFixture.vpcSubnetId!).hasAttribute("readonly")).toBe(true);
      expect(getByDisplayValue(clusterFixture.region).hasAttribute("readonly")).toBe(true);
      expect(queryByRole('EditRegion')).toBeNull();
      expect(getByDisplayValue(clusterFixture.baseAMI!).hasAttribute("readonly")).toBe(true);
      expect(queryByTestId('MaxPlannedUsers')).toBeNull();
      expect(getByDisplayValue(clusterFixture.maxThreadsByInstance.toString()).hasAttribute("readonly")).toBe(true);
    });
  });
});
