import React from 'react';
import { JMeterFile } from '../domain';
import { Modal } from '../Modal';
export function FileRemoveConfirmation({ showModal, setShowModal, handleFileRemove, file, }: {
  showModal: boolean;
  setShowModal: React.Dispatch<React.SetStateAction<boolean>>;
  handleFileRemove: (file: JMeterFile) => void;
  file: JMeterFile;
}) {
  return (<Modal isActive={showModal}>
    <div className={`modal${showModal ? " is-active" : ""}`}>
      <div className="modal-background"></div>
      <div className="modal-content">
        <article className="message is-warning">
          <div className="message-body">
            <p>Are you sure you want to remove this file?</p>
            <div className="field is-grouped is-grouped-centered">
              <p className="control">
                <a className="button is-primary" onClick={() => setShowModal(false)}>
                  No, keep it
                  </a>
              </p>
              <p className="control">
                <button className="button is-danger" onClick={() => handleFileRemove(file)}>
                  Yes, remove it
                  </button>
              </p>
            </div>
          </div>
        </article>
      </div>
    </div>
  </Modal>);
}
