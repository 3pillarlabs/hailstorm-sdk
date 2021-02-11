import React from 'react';
import { shallow, mount } from 'enzyme';
import App from './App';

jest.mock(`./TopNav`, () => ({
  __esModule: true,
  TopNav: () => (
    <div id="TopNav"></div>
  )
}));

jest.mock(`./ProjectList`, () => ({
  __esModule: true,
  ProjectList: () => (
    <div id="ProjectList"></div>
  )
}));

jest.mock(`./ProjectWorkspace`, () => ({
  __esModule: true,
  ProjectWorkspace: () => (
    <div id="ProjectWorkspace"></div>
  )
}));

jest.mock(`./NewProjectWizard`, () => ({
  __esModule: true,
  NewProjectWizard: () => (
    <div id="NewProjectWizard"></div>
  )
}));

describe('<App />', () => {
  it('renders without crashing', () => {
    const component = shallow(<App />);
    expect(component).toContainExactlyOneMatchingElement('AppStateProvider');
    expect(component).toContainExactlyOneMatchingElement('AppNotificationProvider');
    expect(component).toContainExactlyOneMatchingElement('TopNav');
  });

  it('should redirect to /projects from /', () => {
    mount(<App />);
    expect(document.location.hash).toMatch(/\/projects$/);
  });
});
