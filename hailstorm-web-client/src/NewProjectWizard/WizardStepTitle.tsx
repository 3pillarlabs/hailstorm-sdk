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

const circleX = 42;
const circleY = 42;
const radius = 31;
const vertLineStart = radius + 1;

function Step(props: React.PropsWithChildren<WizardStepTitleProps>) {
  return (
    <svg>
      {props.first ? <></> : <Line y2={vertLineStart} />}
      <circle cx={circleX} cy={circleY} r={radius} strokeWidth="1"></circle>
      {props.last ? <></> : <Line y1={vertLineStart} y2={160} />}
      <text x={circleX} y={circleY} textAnchor="middle" dominantBaseline="middle" className={styles.stepTitle}>{props.title}</text>
      <text x="110" y={circleY} textAnchor="middle" dominantBaseline="middle">{props.children}</text>
    </svg>
  );
}

function Line({
  x1, y1, x2, y2, strokeWidth
}:{
  x1?: number;
  y1?: number;
  x2?: number;
  y2: number;
  strokeWidth?: number;
}) {
  return (
    <line x1={x1 || circleX} y1={y1 || 0} x2={x2 || circleX} y2={y2} strokeWidth={strokeWidth || 10}></line>
  );
}
