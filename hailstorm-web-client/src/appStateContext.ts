import React from 'react';
import { AppState, initialState } from "./store";

export interface AppStateContextProps {
  appState: AppState;
  dispatch: React.Dispatch<any>;
}

export const AppStateContext = React.createContext<AppStateContextProps>({
  appState: initialState,
  dispatch: () => new Error('AppStateContext used outside of provider boundary')
});
