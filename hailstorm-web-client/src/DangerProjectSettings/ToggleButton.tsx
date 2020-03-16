import React from 'react';
import styles from './ToggleButton.module.scss';

export interface ToggleButtonProps {
  isPressed: boolean;
  setIsPressed: React.Dispatch<React.SetStateAction<boolean>>;
}

export const ToggleButton: React.FC<ToggleButtonProps> = ({isPressed, setIsPressed, children}) => {
  const clickHandler = (event: React.SyntheticEvent) => {
    event.currentTarget.classList.toggle(styles.pressedState);
    setIsPressed(!isPressed);
    setTimeout(() => window.scrollBy(0, window.scrollY), 0);
  }

  return (
    <button className={`button ${styles.button} is-light`} onClick={clickHandler}>
      {children} <i className={isPressed ? "fa fa-angle-up" : "fa fa-angle-down"} />
    </button>
  );
}
