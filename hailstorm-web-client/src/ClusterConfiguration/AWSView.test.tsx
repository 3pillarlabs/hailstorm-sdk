import React from 'react';
import { fireEvent, render, wait } from '@testing-library/react';
import { AmazonCluster, Project } from '../domain';
import { AWSView } from './AWSView';
import { UpdateClusterAction } from './actions';
import { ClusterService } from '../services/ClusterService';

describe('<AWSView />', () => {
  const cluster: AmazonCluster = {
    id: 123,
    accessKey: 'A',
    secretKey: 's',
    instanceType: 't3a.large',
    maxThreadsByInstance: 100,
    region: 'us-east-1',
    title: 'AWS Cluster',
    type: 'AWS'
  };

  const activeProject: Project = {
    id: 1,
    code: 'abc',
    running: false,
    title: 'ABC'
  };

  const dispatch = jest.fn();

  beforeEach(() => {
    jest.resetAllMocks();
  });

  describe('with an enabled cluster', () => {
    it('should update Max users per instance', async () => {
      const promise: Promise<AmazonCluster> = Promise.resolve({...cluster, maxThreadsByInstance: 50});
      const apiSpy = jest.spyOn(ClusterService.prototype, 'update').mockReturnValue(promise);
      const { findByRole, findByTestId, debug } = render(<AWSView {...{cluster, activeProject, dispatch}} />);
      const input = await findByTestId('Max. Users / Instance');
      fireEvent.focus(input);
      fireEvent.change(input, {target: {value: '200'}});
      fireEvent.blur(input);

      debug(input);
      const updateTrigger = await findByRole('Update Cluster');
      debug(updateTrigger);
      fireEvent.click(updateTrigger);

      await wait(async () => {
        await promise;
        expect(apiSpy).toHaveBeenCalled();
        expect(dispatch).toHaveBeenCalled();
        const action = dispatch.mock.calls[0][0];
        expect(action).toBeInstanceOf(UpdateClusterAction);
      }, {timeout: 1000});
    });
  });

  describe('with a disabled cluster', () => {
    it('should not have update trigger', async () => {
      const { queryAllByRole, queryAllByTestId } = render(
        <AWSView
          {...{cluster: {...cluster, disabled: true}, activeProject, dispatch}}
        />
      );

      const inputs = queryAllByTestId('Max. Users / Instance');
      expect(inputs.length).toBe(0);

      const triggers = queryAllByRole('Update Cluster');
      expect(triggers.length).toBe(0);
    });
  });
});
