import React, { useState } from 'react';
import { ModalProps } from '../Modal';
import styles from './JtlDownloadModal.module.scss';

export interface JtlDownloadContentProps {
  title?: string;
  url?: string;
}

export interface JtlDownloadModalProps extends ModalProps, JtlDownloadContentProps {
  setActive: React.Dispatch<React.SetStateAction<boolean>>;
}

export const JtlDownloadModal: React.FC<JtlDownloadModalProps> = (props) => {
  const [isUnderstood, setUnderstood] = useState(false);
  const {isActive, setActive} = props;

  return (
    <div className={`modal${isActive ? " is-active" : ""}`}>
      <div className="modal-background"></div>
      <div className="modal-content">
        <article className="message is-success">
          <div className={`message-body ${styles.jtlModal}`}>
            <p>
              Your exported results are ready for download.
              This link will <strong>not</strong> be available after you close this window.
            </p>
            <div className="field">
              <div className="control has-text-centered">
                <a className="button is-link is-large" href={props.url} title={props.title} target="_blank">
                  Download
                </a>
              </div>
            </div>
            <div className="field">
              <div className="control">
                <label className="checkbox">
                  <input type="checkbox" checked={isUnderstood} onChange={() => setUnderstood(!isUnderstood)} />
                  I understand that this download link will no longer be available after this window is closed.
                </label>
              </div>
            </div>
            <div className="field">
              <div className="control">
                <button className="button" disabled={!isUnderstood} onClick={() => setActive(!isActive)}>Close</button>
              </div>
            </div>
          </div>
        </article>
      </div>
    </div>
  )
}
