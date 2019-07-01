import React from 'react';
import ReactDOM from 'react-dom';
import { ProjectBar } from './ProjectBar';

it('renders without crashing', () => {
  const div = document.createElement('div');
  ReactDOM.render(<ProjectBar maxColumns={2} />, div);
  ReactDOM.unmountComponentAtNode(div);
});
