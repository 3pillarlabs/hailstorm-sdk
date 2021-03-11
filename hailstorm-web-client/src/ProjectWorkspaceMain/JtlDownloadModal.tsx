import React, { useState } from 'react';
import { LoadingMessage } from '../Loader';
import { ModalProps } from '../Modal';
import styles from './JtlDownloadModal.module.scss';

export interface JtlDownloadContentProps {
  title?: string;
  url?: string;
}

export interface JtlDownloadModalProps extends ModalProps, JtlDownloadContentProps {
  setActive: React.Dispatch<React.SetStateAction<boolean>>;
  contentActive?: boolean;
}

export const JtlDownloadModal: React.FC<JtlDownloadModalProps> = (props) => {
  const [isUnderstood, setUnderstood] = useState(false);

  return (
    <div className={`modal${props.isActive ? " is-active" : ""}`}>
      <div className="modal-background"></div>
      <div className="modal-content">
        {props.contentActive ? (
          <SuccessMessage
            {...props}
            {...{isUnderstood, setUnderstood}}
          />
        ):(
          <WaitingMessage />
        )}
      </div>
    </div>
  )
}

function SuccessMessage({
  url,
  title,
  isUnderstood,
  setUnderstood,
  setActive,
  isActive
}: {
  url?: string;
  title?: string;
  isUnderstood: boolean;
  setUnderstood: React.Dispatch<React.SetStateAction<boolean>>;
  setActive: React.Dispatch<React.SetStateAction<boolean>>;
  isActive: boolean;
}) {
  return (
    <article className="message is-success">
      <div className={`message-body ${styles.modal}`}>
        <p>
          Exported results are ready for download.
          This link will <strong>not</strong> be available after you close this window.
        </p>
        <div className="field">
          <div className="control has-text-centered">
            <a className="button is-link is-large" href={url} title={title} target="_blank">
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
  );
}

function WaitingMessage() {
  return (
    <article className="message is-warning">
      <div className={`message-body ${styles.modal}`}>
        <p>
          <LoadingMessage>
            Waiting for results to be exported...
          </LoadingMessage>
        </p>
      </div>
    </article>
  )
}
