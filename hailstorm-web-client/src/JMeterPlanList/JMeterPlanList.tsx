import React from 'react';
import { JMeter, JMeterFile } from '../domain';
import { EmptyPanel } from '../EmptyPanel';
import styles from '../NewProjectWizard/NewProjectWizard.module.scss';

export interface JMeterPlanListProps {
  showEdit?: boolean;
  jmeter?: JMeter;
  onSelect?: (file: JMeterFile) => void;
  activeFile?: JMeterFile;
  disableEdit?: boolean;
  onEdit?: () => void;
  showDisabled?: boolean;
}

export const JMeterPlanList: React.FC<JMeterPlanListProps> = ({
  showEdit,
  jmeter,
  onSelect,
  activeFile,
  disableEdit,
  onEdit,
  showDisabled
}) => {
  let fileList: JMeterFile[] = [];
  if (jmeter) {
    fileList = showDisabled ? jmeter.files : jmeter.files.filter((v) => !v.disabled);
  }

  return (
    <div className="panel" data-testid="JMeter Plans">
      <div className="panel-heading">
        <div className="level">
          <div className="level-left">
            <div className="level-item">
              <i className="fas fa-feather-alt"></i> JMeter
            </div>
          </div>
          <div className="level-right">
            <div className="level-item">
              {showEdit ? (
              <button className="button is-small" disabled={disableEdit} onClick={onEdit}>
                <i className="far fa-edit"></i> Edit
              </button>)
              : null}
            </div>
          </div>
        </div>
      </div>
      {fileList.length > 0 ? renderPlanList(fileList, onSelect, activeFile) : renderEmptyList()}
    </div>
  );
}

function renderPlanList(
  fileList: JMeterFile[],
  handleSelect?: (file: JMeterFile) => void,
  activeFile?: JMeterFile
): React.ReactNode {
  return fileList.map((plan) => {
    const item = (
      <>
        <span className="panel-icon">
        {plan.dataFile ? (
          <i className="far fa-file" aria-hidden="true" role="Data File"></i>
        ) : (
          <i className="far fa-file-code" aria-hidden="true" role="JMeter Plan"></i>
        )}
        </span>
        {plan.name}
        {plan.disabled && (<span className={`tag is-dark ${styles.titleLabel}`}>disabled</span>)}
      </>
    );

    return handleSelect ? (
      <a
        className={`panel-block${activeFile && activeFile.id === plan.id ? ' is-active' : ''} force-wrap`}
        key={plan.name}
        onClick={() => handleSelect(plan)}
      >
        {item}
      </a>
    ) : (
      <div className="panel-block force-wrap" key={plan.name}>
        {item}
      </div>
    )
  });
}

function renderEmptyList(): React.ReactNode {
  return (<EmptyPanel />);
}
