import React, { useReducer } from 'react';
import {useReducer as useStoreReducer} from 'reinspect';
import { rootReducer, initialState, AppState } from '../store';
import { AppStateContext } from '../appStateContext';

export function AppStateProvider({children}: React.PropsWithChildren<{}>) {
  // const [appState, dispatch] = useReducer(rootReducer, initialState);
  const [appState, dispatch] = useStoreReducer(rootReducer, initialState, (state) => state, "Hailstorm");

  return (
    <AppStateProviderWithProps {...{appState, dispatch}}>
      {children}
    </AppStateProviderWithProps>
  )
}

export function AppStateProviderWithProps({
  appState,
  dispatch,
  children
}: React.PropsWithChildren<{
  appState: AppState,
  dispatch: React.Dispatch<any>
}>) {

  return (
    <AppStateContext.Provider value={{appState, dispatch}}>
      {children}
    </AppStateContext.Provider>
  )
}
