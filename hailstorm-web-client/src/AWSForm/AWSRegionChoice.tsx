import React, { useState, useEffect } from 'react';
import { AWSRegionType, AWSRegionList } from '../ClusterConfiguration/domain';
import { Loader } from '../Loader/Loader';
import { useNotifications } from '../app-notifications';
import { ErrorMessage, Field, Form, Formik } from 'formik';

export function AWSRegionChoice({
  fetchRegions,
  onAWSRegionChange,
  disabled
}: {
  onAWSRegionChange: (region: string, options?: {baseAMI?: string}) => void;
  fetchRegions: () => Promise<AWSRegionList>;
  disabled?: boolean;
}) {
  const {notifyError} = useNotifications();
  const [regionList, setRegionList] = useState<AWSRegionList>();
  const [regions, setRegions] = useState<AWSRegionType[]>([]);
  const [selectedRegion, setSelectedRegion] = useState<AWSRegionType>();
  const [pristineRegion, setPristineRegion] = useState<AWSRegionType>();
  const [validatedBaseAMI, setValidatedBaseAMI] = useState<string>();

  useEffect(() => {
    console.debug('AWSRegionChoice#useEffect()');
    fetchRegions()
      .then((data) => {
        setRegionList(data);
        setSelectedRegion(data.defaultRegion);
        onAWSRegionChange(data.defaultRegion.code);
      })
      .catch((reason) => notifyError(`Failed to fetch region price data`, reason));
  }, []);

  const handleEdit = () => {
    setPristineRegion(selectedRegion);
    setSelectedRegion(undefined);
    if (regionList) setRegions(regionList.regions);
  };

  const handleRegionClick = (code: string) => {
    setValidatedBaseAMI(undefined);
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

  const onCustomRegion: (
    attrs: {
      region: string,
      baseAMI: string
    }) => void = ({region, baseAMI}) => {
      setSelectedRegion({code: region, title: region});
      setValidatedBaseAMI(baseAMI);
      onAWSRegionChange(region, {baseAMI});
  };

  if (selectedRegion && selectedRegion.regions === undefined) {
    return (
      <>
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
        {validatedBaseAMI && (
        <div className="field">
          <label className="label">Base AMI</label>
          <div className="control is-expanded">
            <input readOnly className="input" data-testid="Base AMI" value={validatedBaseAMI} />
          </div>
        </div>
        )}
      </>
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
        {regions.length > 0 ? (
            <Choices
              {...{regions, onCustomRegion, selectedRegion, validatedBaseAMI}}
              onRegionClick={handleRegionClick}
            />
          ) :
          <Loader />
        }
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

function Choices({
  regions,
  onRegionClick,
  onCustomRegion,
  selectedRegion,
  validatedBaseAMI
}:{
  regions: AWSRegionType[];
  onRegionClick: (code: string) => void;
  onCustomRegion: (attrs: {region: string, baseAMI: string}) => void;
  selectedRegion?: AWSRegionType;
  validatedBaseAMI?: string;
}) {
  const [otherOptionsShown, setOtherOptionsShown] = useState(false);

  if (otherOptionsShown) {
    return (
      <CustomRegionForm
        {...{onCustomRegion, selectedRegion, validatedBaseAMI}}
      />
    )
  }

  return (
    <div className="buttons">
      {regions.map((region) => (
      <a
        key={region.code}
        className={`button${region.regions === undefined ? ' is-light': ''}`}
        role="AWSRegionOption"
        onClick={() => onRegionClick(region.code)}
      >
        {region.title}
      </a>
      ))}
      {regions.some((region) => region.regions !== undefined) && (
      <a
        className="button is-info is-inverted"
        role="OtherOption"
        onClick={() => setOtherOptionsShown(true)}
      >
        Other
      </a>
      )}
    </div>
  )
}

function CustomRegionForm({
  onCustomRegion,
  selectedRegion,
  validatedBaseAMI = ''
}:{
  onCustomRegion: (attrs: {region: string, baseAMI: string}) => void;
  selectedRegion?: AWSRegionType;
  validatedBaseAMI?: string;
}) {

  const initialValues = {
    baseAMI: validatedBaseAMI,
    region: selectedRegion ? selectedRegion.code : ''
  };

  return (
    <Formik
      {...{initialValues}}
      onSubmit={(values, {setSubmitting}) => {
        const {baseAMI, region} = values;
        onCustomRegion({region, baseAMI});
        setSubmitting(false);
      }}
      isInitialValid={false}
      validate={(values) => {
        const errors: {[K in keyof typeof values]?: string} = {};
        if (!values.region) {
          errors.region = "AWS Region can't be blank";
        }

        if (!values.baseAMI) {
          errors.baseAMI = "AMI ID can't be blank";
        }

        return errors;
      }}
    >
    {(props) => (
      <div className="content">
        <div className="field">
          <label className="label">AWS Region Code</label>
          <div className="control">
            <Field required name="region" className="input" disabled={props.isSubmitting} placeholder="af-south-2" />
          </div>
          <ErrorMessage name="region" render={(message) => (<p className="help is-danger">{message}</p>)} />
        </div>
        <div className="field">
          <label className="label">AMI ID</label>
          <div className="control">
            <Field required name="baseAMI" className="input" disabled={props.isSubmitting} placeholder="ami-03ba3948f6c37a4b0" />
          </div>
          <p className="help">
            Ubuntu AMI for provisioning the EC2 instance.
            Refer to this <a href="https://cloud-images.ubuntu.com/locator/ec2/" target="_blank">locator</a> to find one.
          </p>
          <ErrorMessage name="baseAMI" render={(message) => (<p className="help is-danger">{message}</p>)} />
        </div>
        <div className="field is-grouped">
          <div className="control">
            <button
              className="button"
              type="button"
              disabled={props.isSubmitting || !props.isValid}
              onClick={props.submitForm}
            >
              Update
            </button>
          </div>
        </div>
      </div>
    )}
    </Formik>
  )
}
