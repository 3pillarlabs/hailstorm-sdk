import React, { useState, useEffect } from 'react';
import { AWSRegionType, AWSRegionList } from './domain';
import { Loader } from '../Loader/Loader';

export function AWSRegionChoice({
  fetchRegions,
  onAWSRegionChange,
  disabled
}: {
  onAWSRegionChange: (value: string) => void;
  fetchRegions: () => Promise<AWSRegionList>;
  disabled?: boolean;
}) {
  const [regionList, setRegionList] = useState<AWSRegionList>();
  const [regions, setRegions] = useState<AWSRegionType[]>([]);
  const [selectedRegion, setSelectedRegion] = useState<AWSRegionType>();
  const [pristineRegion, setPristineRegion] = useState<AWSRegionType>();

  useEffect(() => {
    console.debug('AWSRegionChoice#useEffect()');
    fetchRegions()
      .then((data) => {
        setRegionList(data);
        setSelectedRegion(data.defaultRegion);
        onAWSRegionChange(data.defaultRegion.code);
      })
      .catch((reason) => console.error(reason));
  }, []);

  const handleEdit = () => {
    setPristineRegion(selectedRegion);
    setSelectedRegion(undefined);
    if (regionList) setRegions(regionList.regions);
  };

  const handleRegionClick = (code: string) => {
    const selectedRegion = regions.find((region) => region.code === code);
    setSelectedRegion(selectedRegion);
    if (!selectedRegion) return;

    if (selectedRegion.regions !== undefined) {
      setRegions(selectedRegion.regions);
    } else {
      onAWSRegionChange(selectedRegion.code);
    }
  };

  const handleCancel = () => {
    setSelectedRegion(pristineRegion);
    setPristineRegion(undefined);
  };

  if (selectedRegion && selectedRegion.regions === undefined) {
    return (
      <div className="field has-addons">
        <div className="control is-expanded">
          <input readOnly className="input" value={selectedRegion.title} />
        </div>
        <div className="control">
          {!disabled ? (
          <a className="button" role="EditRegion" onClick={handleEdit}>Edit</a>
          ) : (
          <span className="button is-static is-disabled" role="EditRegion">Edit</span>
          )}
        </div>
      </div>
    )
  }

  return (
    <div className="card">
      {selectedRegion ? (
      <div className="card-header">
        <div className="card-header-title">{selectedRegion.title}</div>
      </div>
      ) : null}
      <div className="card-content">
        {regions.length > 0 ? renderChoices(regions, handleRegionClick) : <Loader />}
      </div>
      {!selectedRegion || selectedRegion.regions !== undefined ? (
      <div className="card-footer">
        <div className="card-footer-item">
          <a className="is-link" onClick={handleCancel}>Cancel</a>
        </div>
      </div>
      ) : null}
    </div>
  );
}

function renderChoices(regions: AWSRegionType[], onClick: (code: string) => void) {
  return (
    <>
    <div className="buttons">
      {regions.map((region) => (
      <a
        key={region.code}
        className={`button${region.regions === undefined ? ' is-light': ''}`}
        role="AWSRegionOption"
        onClick={() => onClick(region.code)}
      >
        {region.title}
      </a>
      ))}
    </div>
    </>
  )
}
