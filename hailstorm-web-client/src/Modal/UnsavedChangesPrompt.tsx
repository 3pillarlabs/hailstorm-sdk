import React, { useState, useEffect, SetStateAction } from 'react';
import { Location } from 'history';
import { Prompt, Redirect } from 'react-router';
import { Modal } from './Modal';
import { ModalConfirmation } from "./ModalConfirmation";

export interface UnsavedChangesPromptProps {
  showModal: boolean;
  setShowModal: React.Dispatch<SetStateAction<boolean>>;
  hasUnsavedChanges: boolean;
  unSavedChangesDeps?: any[] | undefined;
  cancelButtonLabel?: string;
  confirmButtonLabel?: string;
  handleConfirm?: () => void;
  handleCancel?: () => void;
  whiteList?: (location: Location<any>) => boolean;
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
  whiteList,
  delayConfirmation,
  children
}) => {
  const [nextLocation, setNextLocation] = useState<Location>();
  const [okConfirmed, setOkConfirmed] = useState(false);
  const [confirmDisabled, setConfirmDisabled] = useState(true);

  const navAwayHandler = (location: Location<any>) => {
    if (whiteList && whiteList(location)) {
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

  useEffect(() => {
    console.debug('UnsavedChangesPrompt#useEffect(okConfirmed)');
    if (okConfirmed) {
      handleConfirm && handleConfirm();
    }
  }, [okConfirmed]);

  return (
    <>
    <Prompt when={hasUnsavedChanges} message={(nextLocation) => navAwayHandler(nextLocation)} />
    <Modal isActive={showModal}>
      <ModalConfirmation
        cancelButtonLabel={cancelButtonLabel || 'No, Cancel'}
        cancelHandler={modalCancelHandler}
        confirmButtonLabel={confirmButtonLabel || "Yes, I'm sure"}
        confirmHandler={modalConfirmHandler}
        isActive={showModal}
        isConfirmDisabled={delayConfirmation !== false && confirmDisabled}
      >
        {children}
      </ModalConfirmation>
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
