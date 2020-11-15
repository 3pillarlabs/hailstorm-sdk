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
  hourlyCostByCluster,
  setHourlyCostByCluster,
  disabled
}: {
  regionCode: string;
  onChange: (choice: AWSInstanceChoiceOption) => void;
  fetchPricing: (regionCode: string) => Promise<AWSInstanceChoiceOption[]>;
  hourlyCostByCluster?: number;
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
    <>
      <InstanceTypeChoice {...{
        handleSliderChange,
        instanceType,
        maxThreadsByInstance,
        onChange,
        pricingData,
        quickMode,
        setHourlyCostByCluster,
        setInstanceType,
        setQuickMode,
        disabled
      }} />

      <MaxUsersByInstance
        value={maxThreadsByInstance}
        {...{disabled}}
        onChange={(event: { target: { value: string; }; }) => {
          setMaxThreadsByInstance(parseInt(event.target.value));
          onChange(new AWSInstanceChoiceOption({
            maxThreadsByInstance: parseInt(event.target.value),
            instanceType
          }));
        }}
      />

      {quickMode && (<InstanceTypeMeter {...{
        hourlyCostByCluster,
        instanceType,
        numInstances
      }} />)}
    </>
  );
}

function InstanceTypeChoice({
  quickMode,
  handleSliderChange,
  pricingData,
  disabled,
  setHourlyCostByCluster,
  setQuickMode,
  instanceType,
  setInstanceType,
  onChange,
  maxThreadsByInstance
}:{
  quickMode: boolean;
  handleSliderChange: (value: number) => void;
  pricingData: AWSInstanceChoiceOption[];
  disabled?: boolean;
  setHourlyCostByCluster: React.Dispatch<React.SetStateAction<number | undefined>> | undefined;
  setQuickMode: React.Dispatch<React.SetStateAction<boolean>>;
  instanceType: string;
  setInstanceType: React.Dispatch<React.SetStateAction<string>>;
  onChange: (choice: AWSInstanceChoiceOption) => void;
  maxThreadsByInstance: number;
}) {
  return (
    <>
    {quickMode ? (
      <InstanceTypeByUsage {...{
        handleSliderChange,
        pricingData,
        disabled,
        setHourlyCostByCluster,
        setQuickMode
      }} />
    ) : (
      <InstanceTypeInput {...{
        instanceType,
        setInstanceType,
        onChange,
        maxThreadsByInstance,
        disabled,
        handleSliderChange,
        setQuickMode
      }}/>
    )}
    </>
  )
}

function InstanceTypeByUsage({
  handleSliderChange,
  pricingData,
  disabled,
  setHourlyCostByCluster,
  setQuickMode
}:{
  handleSliderChange: (value: number) => void;
  pricingData: AWSInstanceChoiceOption[];
  disabled?: boolean;
  setHourlyCostByCluster: React.Dispatch<React.SetStateAction<number | undefined>> | undefined;
  setQuickMode: React.Dispatch<React.SetStateAction<boolean>>;
}) {
  return (
    <>
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
      {!disabled && (<SwitchMessage
        onClick={() => {
          setHourlyCostByCluster && setHourlyCostByCluster(undefined);
          setQuickMode(false);
        }}
      >
        Specify AWS Instance Type (for advanced users)
      </SwitchMessage>)}
    </>
  )
}

function InstanceTypeInput({
  instanceType,
  setInstanceType,
  onChange,
  maxThreadsByInstance,
  disabled,
  handleSliderChange,
  setQuickMode
}:{
  instanceType: string;
  setInstanceType: React.Dispatch<React.SetStateAction<string>>;
  onChange: (choice: AWSInstanceChoiceOption) => void;
  maxThreadsByInstance: number;
  disabled: boolean | undefined;
  handleSliderChange: (value: number) => void;
  setQuickMode: React.Dispatch<React.SetStateAction<boolean>>;
}) {
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
            onChange={(event: { target: { value: string } }) => {
              setInstanceType(event.target.value);
              onChange(new AWSInstanceChoiceOption({
                instanceType: event.target.value,
                maxThreadsByInstance
              }));
            } }
            {...{ disabled }} />
        </div>
      </div>
      {!disabled && (<SwitchMessage
        onClick={() => {
          handleSliderChange(MIN_VALUE);
          setQuickMode(true);
        }}
      >
        Determine AWS Instance Type by Usage
      </SwitchMessage>)}
    </>
  )
}

function InstanceTypeMeter({
  instanceType,
  numInstances,
  hourlyCostByCluster
}:{
  instanceType: string;
  numInstances: number;
  hourlyCostByCluster?: number;
}) {
  return (
    <div className="level">
      <CenteredLevelItem title="AWS Instance Type" starred={true}>
        {instanceType}
      </CenteredLevelItem>
      <CenteredLevelItem title="# Instances">
        {numInstances}
      </CenteredLevelItem>
      {hourlyCostByCluster && (<CenteredLevelItem title="Cluster Cost" starred={true}>
        ${hourlyCostByCluster.toFixed(4)}
      </CenteredLevelItem>)}
    </div>
  );
}

function SwitchMessage({
  onClick,
  children
}: React.PropsWithChildren<{
  onClick: () => void;
}>): JSX.Element {
  return (
    <div className="notification is-size-7">
      <a className="has-text-link" onClick={onClick}>
        {children}
      </a>
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

export function MaxUsersByInstance({
  value,
  onChange,
  disabled
}:{
  value?: number;
  onChange?: (event: React.ChangeEvent<HTMLInputElement>) => void;
  disabled?: boolean;
}) {
  return (
    <div className="field">
      <label className="label">Max. Users / Instance *</label>
      <div className="control">
        <input
          required
          type="text"
          className="input"
          name="maxThreadsByInstance"
          data-testid="Max. Users / Instance"
          value={value}
          onChange={onChange}
          {...{ disabled }} />
      </div>
    </div>
  )
}
