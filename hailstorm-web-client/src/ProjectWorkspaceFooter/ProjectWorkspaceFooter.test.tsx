import React from 'react';
import { shallow } from 'enzyme';
import { ProjectWorkspaceFooter } from './ProjectWorkspaceFooter';
import { render, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router';

jest.mock('../DangerProjectSettings/TerminateProject', () => ({
  __esModule: true,
  TerminateProject: () => (
    <div id="terminateProject"></div>
  )
}));

jest.mock('../DangerProjectSettings/DeleteProject', () => ({
  __esModule: true,
  DeleteProject: () => (
    <div id="deleteProject"></div>
  )
}));

describe('<ProjectWorkspaceFooter />', () => {
  it('should render without crashing', () => {
    shallow(<ProjectWorkspaceFooter />);
  });

  it('should toggle state', async () => {
    const {findByText} = render(
      <MemoryRouter>
        <ProjectWorkspaceFooter />
      </MemoryRouter>
    );

    const showButton = await findByText('Show them');
    fireEvent.click(showButton);
    const hideButton = await findByText('Hide them');
    expect(hideButton).toBeDefined();
  });
});
