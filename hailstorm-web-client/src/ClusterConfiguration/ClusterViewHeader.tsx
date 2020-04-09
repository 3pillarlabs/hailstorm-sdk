import React from "react";
export function ClusterViewHeader({
  title,
  icon
}: {
  title: string;
  icon: JSX.Element;
}) {
  return (
    <header className="card-header">
      <p className="card-header-title">
        <span className="icon">{icon}</span>
        {title}
      </p>
    </header>
  );
}
