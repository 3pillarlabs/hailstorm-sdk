import React, { useContext } from 'react';
import { render } from '@testing-library/react';
import { AppStateProvider } from './AppStateProvider';
import { AppStateContext } from '../appStateContext';
import { mount } from 'enzyme';

describe('<AppStateProvider />', () => {
  it('should not crash', () => {
    render(<AppStateProvider></AppStateProvider>)
  });

  it('should provide the application state context', () => {
    const AppComponent = () => {
      const {appState, dispatch} = useContext(AppStateContext);
      let dispatchFnSig = 'OK';
      try {
        dispatch('');
      } catch (error) {
        dispatchFnSig = error.toString();
      }

      return (
        <div id="AppComponent">
          {appState && (<span id="appState">OK</span>)}
          {dispatch && (<span id="dispatch">{dispatchFnSig}</span>)}
        </div>
      );
    };

    const component = mount(
      <AppStateProvider>
        <AppComponent />
      </AppStateProvider>
    );

    expect(component.find('#appState')).toExist();
    expect(component.find('#dispatch').text()).not.toMatch('AppStateContext used outside of provider boundary');
  });

});
