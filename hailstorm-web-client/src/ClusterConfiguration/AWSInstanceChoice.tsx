import React, { useState, useEffect } from 'react';
import { NonLinearSlider } from './NonLinearSlider';
import { computeChoice, maxThreadsByCluster } from './AWSInstanceCalculator';
import { AWSInstanceChoiceOption } from './domain';
import { Loader } from '../Loader/Loader';

const MIN_VALUE = 50;

export function AWSInstanceChoice({
  regionCode,
  onChange,
  fetchPricing,
  setHourlyCostByCluster,
  disabled
}: {
  regionCode: string;
  onChange: (choice: AWSInstanceChoiceOption) => void;
  fetchPricing: (regionCode: string) => Promise<AWSInstanceChoiceOption[]>;
  setHourlyCostByCluster?: React.Dispatch<React.SetStateAction<number | undefined>>;
  disabled?: boolean;
}) {
  const [pricingData, setPricingData] = useState<AWSInstanceChoiceOption[]>([]);
  const [instanceType, setInstanceType] = useState<string>('');
  const [maxThreadsByInstance, setMaxThreadsByInstance] = useState<number>(0);
  const [numInstances, setNumInstances] = useState<number>(0);
  const [quickMode, setQuickMode] = useState(true);
  const [sliderValue, setSliderValue] = useState(MIN_VALUE);

  const handleSliderChange = (value: number, data?: AWSInstanceChoiceOption[]) => {
    setSliderValue(value);
    const choice = computeChoice(value, pricingData && pricingData.length > 0 ? pricingData : data!);
    setInstanceType(choice.instanceType);
    setMaxThreadsByInstance(choice.maxThreadsByInstance);
    setNumInstances(choice.numInstances);
    onChange(choice);
    return choice;
  }

  useEffect(() => {
    console.debug('AWSInstanceChoice#useEffect(regionCode)');
    if (!quickMode) return;

    fetchPricing(regionCode)
      .then((data) => {
        setPricingData(data);
        const choice = handleSliderChange(sliderValue, data);
        setHourlyCostByCluster && setHourlyCostByCluster(choice.hourlyCostByCluster());
      })
      .catch((reason) => console.error(reason));
  }, [regionCode]);

  if (pricingData.length === 0) {
    return <Loader />;
  }

  return (
    <div className="card">
      <div className="card-header">
        <p className="card-header-title">AWS Instance</p>
      </div>
      <div className="card-content">
        {quickMode ? (
          <div className="level">
            <CenteredLevelItem title="AWS Instance Type" starred={true}>
              {instanceType}
            </CenteredLevelItem>
            <CenteredLevelItem title="Max. Users / Instance" starred={true}>
              {maxThreadsByInstance}
            </CenteredLevelItem>
            <CenteredLevelItem title="# Instances">
              {numInstances}
            </CenteredLevelItem>
          </div>
      ) : (
          <CustomInputSection
            {...{
              instanceType,
              setInstanceType,
              onChange,
              maxThreadsByInstance,
              setMaxThreadsByInstance,
              disabled,
            }}
          />
        )}
        {!disabled && (
          <SwitchMessage
            {...{
              quickMode,
              setQuickMode,
              setHourlyCostByCluster,
              handleSliderChange,
            }}
          />
        )}
        {quickMode && (
          <div className="field">
            <div className="control">
              <NonLinearSlider
                initialValue={MIN_VALUE}
                onChange={handleSliderChange}
                step={50}
                maximum={maxThreadsByCluster(pricingData)}
                minimum={MIN_VALUE}
                {...{ disabled }}
              />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function CustomInputSection({
  instanceType,
  setInstanceType,
  onChange,
  maxThreadsByInstance,
  setMaxThreadsByInstance,
  disabled
}: {
  instanceType: string;
  setInstanceType: React.Dispatch<React.SetStateAction<string>>;
  onChange: (choice: AWSInstanceChoiceOption) => void,
  maxThreadsByInstance: number,
  disabled: boolean | undefined,
  setMaxThreadsByInstance: React.Dispatch<React.SetStateAction<number>>
}): JSX.Element {
  return (
    <>
      <div className="field">
        <label className="label">AWS Instance Type *</label>
        <div className="control">
          <input
            required
            type="text"
            className="input"
            name="awsInstanceType"
            data-testid="AWS Instance Type"
            value={instanceType}
            onChange={(event: { target: { value: string; }; }) => {
              setInstanceType(event.target.value);
              onChange(new AWSInstanceChoiceOption({
                instanceType: event.target.value,
                maxThreadsByInstance
              }));
            } }
            {...{ disabled }} />
        </div>
      </div>
      <div className="field">
        <label className="label">Max. Users / Instance *</label>
        <div className="control">
          <input
            required
            type="text"
            className="input"
            name="maxThreadsByInstance"
            data-testid="Max. Users / Instance"
            value={maxThreadsByInstance}
            onChange={(event: { target: { value: string; }; }) => {
              setMaxThreadsByInstance(parseInt(event.target.value));
              onChange(new AWSInstanceChoiceOption({
                maxThreadsByInstance: parseInt(event.target.value),
                instanceType
              }));
            } }
            {...{ disabled }} />
        </div>
      </div>
      <div className="field">
        <label className="label"># Instances</label>
        <div className="control">
          <input className="input" type="text" placeholder="Calculated automatically" disabled />
        </div>
      </div>
    </>
  );
}

function SwitchMessage({
  quickMode,
  setHourlyCostByCluster,
  handleSliderChange,
  setQuickMode
}: {
  quickMode: boolean;
  setHourlyCostByCluster: React.Dispatch<React.SetStateAction<number | undefined>> | undefined;
  handleSliderChange: (value: number, data?: AWSInstanceChoiceOption[] | undefined) => AWSInstanceChoiceOption;
  setQuickMode: React.Dispatch<React.SetStateAction<boolean>>
}): JSX.Element {

  const labelText = quickMode ? 'Determine by usage' : 'Specify yourself';
  const link = (<a
    className="has-text-link"
    onClick={() => {
      if (quickMode) {
        setHourlyCostByCluster && setHourlyCostByCluster(undefined);
      } else {
        handleSliderChange(MIN_VALUE);
      }

      setQuickMode(!quickMode);
    } }
  >
    {quickMode ? 'Specify yourself' : 'Determine by usage'}
  </a>);

  return (
  <div className="notification is-size-7">
    {labelText} or {link}
  </div>
  );
}

function CenteredLevelItem({
  title,
  children,
  starred
}: React.PropsWithChildren<{title: string, starred?: boolean}>) {
  const heading = starred ? `${title} *` : title;
  return (
    <div className="level-item has-text-centered">
      <div>
        <p className="heading">{heading}</p>
        <p className="title" data-testid={title}>{children}</p>
      </div>
    </div>
  )
}
