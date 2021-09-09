import React from 'react';


export function ModalPrompt({
  isActive,
  closeHandler,
  messageType = 'success',
  isCloseDisabled,
  classModifiers,
  children
}: React.PropsWithChildren<{
  isActive: boolean;
  closeHandler?: () => any;
  messageType?: 'success' | 'warning' | 'danger';
  isCloseDisabled?: boolean;
  classModifiers?: string;
}>) {
  return (
    <div className={`modal${isActive ? " is-active" : ""} ${classModifiers}`}>
      <div className="modal-background"></div>
      <div className="modal-content">
        <article className={`message is-${messageType}`}>
          <div className="message-body">
            {children}
            {closeHandler && (<div className="field">
              <div className="control">
                <button className="button" disabled={isCloseDisabled} onClick={closeHandler}>Close</button>
              </div>
            </div>)}
          </div>
        </article>
      </div>
    </div>
  );
}
