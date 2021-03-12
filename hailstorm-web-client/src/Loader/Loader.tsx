import React from 'react';
import styles from './Loader.module.scss';

export enum LoaderSize {
  APP = 'app',
  COMPONENT = 'component'
}

export interface LoaderProps {
  size?: LoaderSize
}

export const Loader: React.FC<LoaderProps> = ({size = LoaderSize.COMPONENT}) => {
  return (
    <div className={loaderClass(size)}>
      <LoaderElement />
    </div>
  );
}

export function LoadingMessage({children}: React.PropsWithChildren<{}>) {
  return (
    <span className="icon-text">
      <span className="icon">
        <LoaderElement />
      </span>
      <span>{children}</span>
    </span>
  )
}

function loaderClass(size: LoaderSize) {
  let loaderCssClass: string | undefined = undefined;
  switch (size) {
    case LoaderSize.APP:
      loaderCssClass = styles.appLoader;
      break;

    default:
      loaderCssClass = styles.tinyLoader;
      break;
  }
  return loaderCssClass;
}

function LoaderElement() {
  return (
    <i className="fas fa-sync-alt fa-spin"></i>
  );
}
