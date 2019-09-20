import React from 'react';
import styles from './NewProjectWizard.module.scss';
import { Link } from 'react-router-dom';

export interface WizardStepTitleProps {
  title: string;
  linkTo: string;
  first?: boolean;
  last?: boolean;
  isActive?: boolean;
  done?: boolean;
  reachable?: boolean;
  onClick?: () => void;
}

export const WizardStepTitle: React.FC<WizardStepTitleProps> = (props) => {
  let statusClassName = undefined;
  if (props.done) statusClassName = styles.success;
  if (props.isActive) statusClassName = styles.active;

  let stepElement = undefined;
  if (props.reachable) {
    stepElement = (
      <Link to={props.linkTo} className={`${styles.step} ${statusClassName}`} onClick={props.onClick}>
        <Step {...props} />
      </Link>
    );
  } else {
    stepElement = (
      <div className={`${styles.step} ${statusClassName}`}>
        <Step {...props} />
      </div>
    );
  }

  return stepElement;
}

function Step(props: React.PropsWithChildren<WizardStepTitleProps>) {
  return (
    <svg>
      {props.first ? <></> : <line x1="42" y1="0" x2="42" y2="32" strokeWidth="10"></line>}
      <circle cx="42" cy="42" r="31" strokeWidth="1"></circle>
      {props.last ? <></> : <line x1="42" y1="32" x2="42" y2="160" strokeWidth="10"></line>}
      <text x="42" y="42" textAnchor="middle" dominantBaseline="middle" className={styles.stepTitle}>{props.title}</text>
      <text x="110" y="42" textAnchor="middle" dominantBaseline="middle">{props.children}</text>
    </svg>
  );
}
