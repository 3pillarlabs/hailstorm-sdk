import React, { useReducer } from 'react';
import './App.scss';
import { TopNav } from './TopNav';
import { ProjectWorkspace } from './ProjectWorkspace';
import { ProjectList } from './ProjectList';
import { Route, HashRouter, Redirect } from 'react-router-dom';
import { NewProjectWizard } from './NewProjectWizard';
import { rootReducer, initialState } from './store';
import { AppStateContext } from './appStateContext';

const App: React.FC = () => {
  const [appState, dispatch] = useReducer(rootReducer, initialState);

  return (
    <AppStateContext.Provider value={{appState, dispatch}}>
      <HashRouter>
        <TopNav />
        <main>
          <Route exact path="/" render={() => (<Redirect to="/projects" />)} />
          <Route path="/projects" component={ProjectList} exact={true} />
          <Route path="/projects/:id" component={ProjectWorkspace} />
          <Route path="/wizard/projects/:id" component={NewProjectWizard} />
        </main>
      </HashRouter>
    </AppStateContext.Provider>
  );
};

export default App;
