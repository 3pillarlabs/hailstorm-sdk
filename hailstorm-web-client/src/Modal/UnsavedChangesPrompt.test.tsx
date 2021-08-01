import React from 'react';
import { shallow } from "enzyme";
import { UnsavedChangesPrompt, windowUnloadEffect, UnsavedChangesPromptProps } from "./UnsavedChangesPrompt";
import { fireEvent } from '@testing-library/dom';
import { render } from '@testing-library/react';
import { MemoryRouter, Route } from 'react-router';
import { Link } from 'react-router-dom';

jest.mock('./Modal', () => ({
  __esModule: true,
  Modal: (({isActive, children}) => (
    (isActive ? <div id="modal">{children}</div> : null)
  )) as React.FC<{isActive: boolean}>
}));

describe('<UnsavedChangesPrompt />', () => {
  it('should render without crashing', () => {
    shallow(<UnsavedChangesPrompt hasUnsavedChanges={false} setShowModal={jest.fn()} showModal={false} />)
  });

  describe('window beforeunload', () => {
    it('should prompt if there are unsaved changes', async () => {
      const effect = windowUnloadEffect(true);
      const actionListeners: {[key: string]: ((ev: Event) => void)} = {};
      const addListenerSpy = jest.spyOn(window, 'addEventListener').mockImplementation((key: string, listener: any) => {
        actionListeners[key] = listener;
      });

      const cb = effect() as (() => void | undefined);
      expect(addListenerSpy).toBeCalled();
      const event = new Event('beforeunload', {cancelable: true});
      actionListeners['beforeunload'](event);
      expect(event.returnValue).toEqual(false);
      const removeListenerSpy = jest.spyOn(window, 'removeEventListener');
      cb();
      expect(removeListenerSpy).toBeCalled();
    });

    it('should not prompt if there are no unsaved changes', () => {
      const effect = windowUnloadEffect(false);
      const actionListeners: {[key: string]: ((ev: Event) => void)} = {};
      const addListenerSpy = jest.spyOn(window, 'addEventListener').mockImplementation((key: string, listener: any) => {
        actionListeners[key] = listener;
      });

      const cb = effect() as (() => void | undefined);
      expect(addListenerSpy).toBeCalled();
      const event = new Event('beforeunload', {cancelable: true});
      actionListeners['beforeunload'](event);
      expect(event.returnValue).toEqual(true);
    });
  });

  it('should redirect to next location if user confirms prompt', async () => {
    jest.useFakeTimers();
    const CurrentComponent = () => {
      return (
        <div id="currentComponent">
          <UnsavedChangesPrompt
            showModal={true}
            setShowModal={jest.fn()}
            hasUnsavedChanges={true}
            confirmButtonLabel="OK, Next"
          />
          CURRENT
          <Link to="/next">Next</Link>
        </div>
      );
    };

    const NextComponent = () => {
      return (
        <div id="nextComponent">
          NEXT
        </div>
      );
    };

    const {findByText} = render(
      <MemoryRouter initialEntries={['/current']}>
        <Route exact path="/current" component={CurrentComponent} />
        <Route exact path="/next" component={NextComponent} />
      </MemoryRouter>
    );

    const nextLink = await findByText('Next');
    fireEvent.click(nextLink);
    jest.runAllTimers();
    const confirmBtn = await findByText('OK, Next');
    fireEvent.click(confirmBtn);
    const nextComponentText = await findByText('NEXT');
    expect(nextComponentText.innerHTML).toEqual('NEXT');
  });
});
