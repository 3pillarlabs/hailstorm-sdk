import React from 'react';
import './App.scss';
import { TopNav } from './TopNav';
import { ProjectWorkspace } from './ProjectWorkspace';

const App: React.FC = () => {
  return (
    <>
    <TopNav></TopNav>
    <main>
      <ProjectWorkspace></ProjectWorkspace>
    </main>
    </>
  );
}

export default App;
