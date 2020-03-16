import React from 'react';

export function EmptyPanel({rowsCount}: {rowsCount?: number}) {
  const rows = Array.from(Array(rowsCount || 3), (_, k) => (<div className="panel-block" key={k}></div>));
  return (
    <>
      {rows}
    </>
  );
}
