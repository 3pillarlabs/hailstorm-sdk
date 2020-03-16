import React from 'react';
import ReactDOM from 'react-dom';

export interface ModalProps {
  isActive: boolean;
}

export const Modal: React.FC<ModalProps> = (props) => {
  return props.isActive ? ReactDOM.createPortal(props.children, document.getElementById('modal-root') as Element) : null;
}
