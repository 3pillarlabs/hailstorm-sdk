import React from 'react';
import './App.scss';
import { TopNav } from './TopNav';
import { ProjectWorkspace } from './ProjectWorkspace';
import { ProjectList } from './ProjectList';
import { Route, HashRouter } from 'react-router-dom';
import { NewProjectWizard } from './NewProjectWizard';

const App: React.FC = () => {
  return (
    <HashRouter>
      <TopNav></TopNav>
      <main>
        <Route path="/" component={ProjectList} exact={true} />
        <Route path="/projects" component={ProjectList} exact={true} />
        <Route path="/projects/:id" component={ProjectWorkspace} />
        <Route path="/wizard/projects/:id" component={NewProjectWizard} />
      </main>
    </HashRouter>
  );
}

export default App;
