import React from 'react';
import { shallow } from 'enzyme';
import { ProjectWorkspaceMain } from './ProjectWorkspaceMain';

describe('<ProjectWorkspaceMain />', () => {
  it('should render without crashing', () => {
    shallow(<ProjectWorkspaceMain />);
  });
});
