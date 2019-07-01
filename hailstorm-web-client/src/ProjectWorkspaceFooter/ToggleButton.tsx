import React from 'react';
import styles from './ToggleButton.module.scss';

export interface ToggleButtonProps {
  isPressed: boolean;
  dispatch: React.Dispatch<React.SetStateAction<boolean>>;
}

export const ToggleButton: React.FC<ToggleButtonProps> = (props) => {
  const clickHandler = (event: React.SyntheticEvent) => {
    event.currentTarget.classList.toggle("is-hovered");
    props.dispatch(!props.isPressed);
  }

  return (
    <button className={`button ${styles.button} is-light`} onClick={clickHandler}>
      {props.children} <i className={props.isPressed ? "fa fa-angle-up" : "fa fa-angle-down"} />
    </button>
  );
}
