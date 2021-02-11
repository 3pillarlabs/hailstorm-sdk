import React from 'react';
import './App.scss';
import { TopNav } from './TopNav';
import { ProjectWorkspace } from './ProjectWorkspace';
import { ProjectList } from './ProjectList';
import { Route, HashRouter, Redirect } from 'react-router-dom';
import { NewProjectWizard } from './NewProjectWizard';
import { AppStateProvider } from './AppStateProvider';
import { AppNotificationProvider } from './AppNotificationProvider';

const App: React.FC = () => {

  return (
    <AppStateProvider>
      <AppNotificationProvider>
        <HashRouter>
          <TopNav />
          <main>
            <Route exact path="/" render={() => (<Redirect to="/projects" />)} />
            <Route path="/projects" component={ProjectList} exact={true} />
            <Route path="/projects/:id" component={ProjectWorkspace} />
            <Route path="/wizard/projects/:id" component={NewProjectWizard} />
          </main>
        </HashRouter>
      </AppNotificationProvider>
    </AppStateProvider>
  );
};

export default App;
