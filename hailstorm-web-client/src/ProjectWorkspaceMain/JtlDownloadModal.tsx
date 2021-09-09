import React, { useState } from 'react';
import { LoadingMessage } from '../Loader';
import { ModalProps } from '../Modal';
import { ModalPrompt } from '../Modal/ModalPrompt';
import styles from './JtlDownloadModal.module.scss';

export interface JtlDownloadContentProps {
  title?: string;
  url?: string;
}

export interface JtlDownloadModalProps extends ModalProps, JtlDownloadContentProps {
  setActive: React.Dispatch<React.SetStateAction<boolean>>;
  contentActive?: boolean;
}

export const JtlDownloadModal: React.FC<JtlDownloadModalProps> = ({
  contentActive,
  isActive,
  setActive,
  url,
  title
}) => {
  const [isUnderstood, setUnderstood] = useState(false);
  const messageType = contentActive ? 'success' : 'warning';
  return (
    <ModalPrompt
      {...{messageType}}
      isActive={isActive}
      classModifiers={styles.modal}
      closeHandler={() => setActive(!isActive)}
      isCloseDisabled={!isUnderstood}
    >
    {contentActive ? (
      <SuccessMessage {...{isUnderstood, setUnderstood, url, title}} />
    ):(
      <WaitingMessage />
    )}
    </ModalPrompt>
  )
}

function SuccessMessage({
  url,
  title,
  isUnderstood,
  setUnderstood
}: {
  url?: string;
  title?: string;
  isUnderstood: boolean;
  setUnderstood: React.Dispatch<React.SetStateAction<boolean>>;
}) {
  return (
    <>
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
    </>
  );
}

function WaitingMessage() {
  return (
    <p>
      <LoadingMessage>
        Waiting for results to be exported...
      </LoadingMessage>
    </p>
  )
}
