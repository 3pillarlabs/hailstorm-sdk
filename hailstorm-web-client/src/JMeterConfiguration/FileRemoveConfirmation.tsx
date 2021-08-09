import React from 'react';
import { JMeterFile } from '../domain';
import { Modal } from '../Modal';
import { ModalConfirmation } from '../Modal/ModalConfirmation';

export function FileRemoveConfirmation({
  showModal,
  setShowModal,
  handleFileRemove,
  file
}: {
  showModal: boolean;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  handleFileRemove: (file: JMeterFile) => void;
  file: JMeterFile;
}) {
  return (
    <Modal isActive={showModal}>
      <ModalConfirmation
        cancelHandler={() => setShowModal(false)}
        cancelButtonLabel="No, keep it"
        confirmHandler={() => handleFileRemove(file)}
        confirmButtonLabel="Yes, remove it"
        isActive={showModal}
        messageType="warning"
      >
        <p>Are you sure you want to remove this file?</p>
      </ModalConfirmation>
    </Modal>
  );
}
