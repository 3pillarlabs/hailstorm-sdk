import React, { useContext } from 'react';
import { AppState, initialState } from "./store";

export interface AppStateContextProps {
  appState: AppState;
  dispatch: React.Dispatch<any>;
}

export const AppStateContext = React.createContext<AppStateContextProps>({
  appState: initialState,
  dispatch: () => { throw new Error('AppStateContext used outside of provider boundary') }
});

export function useAppState() {
  return useContext(AppStateContext);
}
