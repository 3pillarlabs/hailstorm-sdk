import React from 'react';
import styles from './Loader.module.scss';

export enum LoaderSize {
  APP = 'app'
}

export interface LoaderProps {
  size: LoaderSize
}

export const Loader: React.FC<LoaderProps> = (props) => {
  let loaderCssClass: string | undefined = undefined;
  switch (props.size) {
    case LoaderSize.APP:
      loaderCssClass = styles.appLoader;
      break;

    default:
      loaderCssClass = styles.tinyLoader;
      break;
  }
  return (
    <div className={loaderCssClass}>
      <i className="fas fa-sync-alt fa-spin"></i>
    </div>
  );
}
