import React from 'react';


export function ModalConfirmation({
  isActive,
  classModifiers,
  messageType = 'danger',
  cancelButtonLabel = 'Cancel',
  confirmButtonLabel = 'OK',
  cancelHandler,
  confirmHandler,
  isConfirmDisabled,
  children
}: React.PropsWithChildren<{
  isActive: boolean;
  cancelHandler: () => any;
  confirmHandler: () => any;
  isConfirmDisabled?: boolean;
  classModifiers?: string;
  messageType?: 'success' | 'warning' | 'danger';
  cancelButtonLabel?: string;
  confirmButtonLabel?: string;
}>) {
  return (
    <div className={`modal${isActive ? " is-active" : ""}  ${classModifiers || ''}`}>
      <div className="modal-background"></div>
      <div className="modal-content">
        <article className={`message is-${messageType || "danger"}`}>
          <div className="message-body">
            {children}
            <div className="field is-grouped is-grouped-centered">
              <p className="control">
                <a className="button is-primary" onClick={cancelHandler}>
                  {cancelButtonLabel}
                </a>
              </p>
              <p className="control">
                <button disabled={isConfirmDisabled} className="button is-danger" onClick={confirmHandler}>
                  {confirmButtonLabel}
                </button>
              </p>
            </div>
          </div>
        </article>
      </div>
    </div>
  );
}
