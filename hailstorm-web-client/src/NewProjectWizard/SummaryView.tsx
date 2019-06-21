import React from 'react';

export interface SummaryViewProps {
  transition: () => void;
}

export const SummaryView: React.FC<SummaryViewProps> = (props) => {
  return (
    <>
    <h3 className="title is-3">Review</h3>
    <button className="button is-success" onClick={props.transition}>Done</button>
    </>
  )
}
