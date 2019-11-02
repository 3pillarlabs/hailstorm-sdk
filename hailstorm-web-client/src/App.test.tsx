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
  TopNav: () => (
    <div id="ProjectList"></div>
  )
}));

jest.mock(`./ProjectWorkspace`, () => ({
  __esModule: true,
  TopNav: () => (
    <div id="ProjectWorkspace"></div>
  )
}));

jest.mock(`./NewProjectWizard`, () => ({
  __esModule: true,
  TopNav: () => (
    <div id="NewProjectWizard"></div>
  )
}));

describe('<App />', () => {
  it('renders without crashing', () => {
    shallow(<App />);
  });

  it('should redirect to /projects from /', () => {
    mount(<App />);
    expect(document.location.hash).toMatch(/\/projects$/);
  });
});
