import React from 'react';

export const DeleteProject: React.FC<{isPressed: boolean}> = ({isPressed}) => {
  return (
    <article className={isPressed ? "message is-danger" : "message is-danger is-hidden"}>
      <div className="message-body">
        <div className="columns">
          <div className="column is-3">
            <button className="button is-danger">
              <i className="fas fa-trash"></i>&nbsp; Delete this project
            </button>
          </div>
          <div className="column is-9">
            <article>
              <p>
                If you delete this project, you will not be able to run the tests again. Please ensure:
              </p>
              <ul>
                <li key="line-1">Data you need is exported.</li>
                <li key="line-2">There are no on-going operations.</li>
              </ul>
            </article>
          </div>
        </div>
      </div>
    </article>
  );
};
