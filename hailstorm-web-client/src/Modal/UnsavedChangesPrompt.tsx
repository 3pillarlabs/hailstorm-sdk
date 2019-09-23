import React, { useState, useEffect, SetStateAction } from 'react';
import { Location } from 'history';
import { Prompt, Redirect } from 'react-router';
import { Modal } from './Modal';

export interface UnsavedChangesPromptProps {
  showModal: boolean;
  setShowModal: React.Dispatch<SetStateAction<boolean>>;
  hasUnsavedChanges: boolean;
  unSavedChangesDeps?: any[] | undefined;
  cancelButtonLabel?: string;
  confirmButtonLabel?: string;
  handleConfirm?: () => void;
  handleCancel?: () => void;
  shouldUpdateNavChange?: (location: Location<any>) => boolean;
  delayConfirmation?: boolean;
}

const CONFIRM_DELAY_MS = 3000;

export const UnsavedChangesPrompt: React.FC<UnsavedChangesPromptProps> = ({
  showModal,
  setShowModal,
  hasUnsavedChanges,
  unSavedChangesDeps,
  cancelButtonLabel,
  confirmButtonLabel,
  handleConfirm,
  handleCancel,
  shouldUpdateNavChange,
  delayConfirmation,
  children
}) => {
  const [nextLocation, setNextLocation] = useState<Location>();
  const [okConfirmed, setOkConfirmed] = useState(false);
  const [confirmDisabled, setConfirmDisabled] = useState(true);

  const navAwayHandler = (location: Location<any>) => {
    if (shouldUpdateNavChange && !shouldUpdateNavChange(location)) {
      return true;
    }

    if (!okConfirmed) {
      setShowModal(true);
    }

    setNextLocation(location);
    return okConfirmed;
  };

  const modalConfirmHandler = () => {
    setShowModal(false);
    setOkConfirmed(true);
    handleConfirm && handleConfirm();
  }

  const modalCancelHandler = () => {
    setShowModal(false);
    handleCancel && handleCancel();
  }

  useEffect(windowUnloadEffect(hasUnsavedChanges), unSavedChangesDeps);

  useEffect(() => {
    console.debug('UnsavedChangesPrompt#useEffect(showModal)');
    if (showModal) {
      setConfirmDisabled(true);
      setTimeout(() => setConfirmDisabled(false), CONFIRM_DELAY_MS);
    } else {
      setConfirmDisabled(false);
    }
  }, [showModal]);

  return (
    <>
    <Prompt when={hasUnsavedChanges} message={(nextLocation) => navAwayHandler(nextLocation)} />
    <Modal isActive={showModal}>
      <div className={`modal${showModal ? " is-active" : ""}`}>
        <div className="modal-background"></div>
        <div className="modal-content">
          <article className="message is-danger">
            <div className="message-body">
              {children}
              <div className="field is-grouped is-grouped-centered">
                <p className="control">
                  <a className="button is-primary" onClick={modalCancelHandler}>
                    {cancelButtonLabel || 'No, Cancel'}
                  </a>
                </p>
                <p className="control">
                  <button disabled={delayConfirmation !== false && confirmDisabled} className="button is-danger" onClick={modalConfirmHandler}>
                    {confirmButtonLabel || "Yes, I'm sure"}
                  </button>
                </p>
              </div>
            </div>
          </article>
        </div>
      </div>
    </Modal>
    {okConfirmed && nextLocation && <Redirect to={nextLocation} />}
    </>
  );
}

export function windowUnloadEffect(hasUnsavedChanges: boolean): React.EffectCallback {
  return () => {
    console.debug('UnsavedChangesPrompt#useEffect()');
    const listener = function (ev: BeforeUnloadEvent) {
      if (hasUnsavedChanges) {
        ev.preventDefault();
        ev.returnValue = false;
      }
      else {
        delete ev['returnValue'];
      }
    };
    window.addEventListener('beforeunload', listener);
    return () => {
      window.removeEventListener('beforeunload', listener);
    };
  };
}
