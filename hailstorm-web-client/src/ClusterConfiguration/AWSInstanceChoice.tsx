import React, { useState, useEffect } from 'react';
import { NonLinearSlider } from './NonLinearSlider';
import { computeChoice, maxThreadsByCluster } from './AWSInstanceCalculator';
import { AWSInstanceChoiceOption } from './domain';
import { Loader, LoadingMessage } from '../Loader';
import { Field } from 'formik';
import { useNotifications } from '../app-notifications';
import { Modal } from '../Modal';
import { ModalConfirmation } from '../Modal/ModalConfirmation';

const MIN_PLANNED_USERS = 50;
const DEFAULT_THREADS_BY_INST = 10;

export function AWSInstanceChoice({
  regionCode,
  onChange,
  fetchPricing,
  hourlyCostByCluster,
  setHourlyCostByCluster,
  disabled,
  savedMaxThreadsByInstance,
  savedInstanceType
}: {
  regionCode: string;
  onChange: (choice: AWSInstanceChoiceOption) => void;
  fetchPricing: (regionCode: string) => Promise<AWSInstanceChoiceOption[]>;
  hourlyCostByCluster?: number;
  setHourlyCostByCluster?: React.Dispatch<React.SetStateAction<number | undefined>>;
  disabled?: boolean;
  savedMaxThreadsByInstance?: number;
  savedInstanceType?: string;
}) {
  const {notifyInfo, notifyWarning} = useNotifications();
  const [pricingData, setPricingData] = useState<AWSInstanceChoiceOption[]>([]);
  const [instanceType, setInstanceType] = useState<string>('');
  const [maxThreadsByInstance, setMaxThreadsByInstance] = useState<number>(DEFAULT_THREADS_BY_INST);
  const [numInstances, setNumInstances] = useState<number>(1);
  const [quickMode, setQuickMode] = useState(true);
  const [maxPlannedThreads, setMaxPlannedThreads] = useState(MIN_PLANNED_USERS);

  const handleSliderChange = (value: number, data?: AWSInstanceChoiceOption[]) => {
    setMaxPlannedThreads(value);
    const choice = computeChoice(value, data ? data : pricingData);
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
        if (!savedInstanceType) {
          handleSliderChange(maxPlannedThreads, data);
          notifyInfo(`Cluster cost updated for ${regionCode}`);
        }
      })
      .catch((reason) => notifyWarning(`Failed to update cluster cost: ${reason instanceof Error ? reason.message : reason}`));
  }, [regionCode]);

  useEffect(() => {
    if (savedMaxThreadsByInstance) {
      setMaxThreadsByInstance(savedMaxThreadsByInstance);
      setQuickMode(false);
    }
  }, [savedMaxThreadsByInstance]);

  useEffect(() => {
    if (savedInstanceType) {
      setInstanceType(savedInstanceType);
    }
  }, [savedInstanceType]);

  if (pricingData.length === 0) {
    return <Loader />;
  }

  const handleMaxUsersByInstChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    let new_value = DEFAULT_THREADS_BY_INST;
    if (event.target.value) {
      new_value = parseInt(event.target.value);
    } else if (pricingData.length > 0) {
      new_value = computeChoice(maxPlannedThreads, pricingData).maxThreadsByInstance;
    }

    setMaxThreadsByInstance(new_value);

    const nextNumInstances = Math.ceil(maxPlannedThreads / new_value);
    setNumInstances(nextNumInstances);

    const matchingOption = pricingData.find((option) => option.instanceType === instanceType);

    const nextOption = new AWSInstanceChoiceOption({
      maxThreadsByInstance: new_value,
      instanceType,
      numInstances: nextNumInstances,
      hourlyCostByInstance: matchingOption ? matchingOption.hourlyCostByInstance : undefined
    });

    onChange(nextOption);
  };

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
        onChange={handleMaxUsersByInstChange}
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
            initialValue={MIN_PLANNED_USERS}
            onChange={handleSliderChange}
            step={50}
            maximum={maxThreadsByCluster(pricingData)}
            minimum={MIN_PLANNED_USERS}
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
  const [showSwitchConfirmation, setShowSwitchConfirmation] = useState(false);

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
        onClick={() => setShowSwitchConfirmation(true)}
      >
        Determine AWS Instance Type by Usage
      </SwitchMessage>)}

      <Modal isActive={showSwitchConfirmation}>
        <ModalConfirmation
          isActive={showSwitchConfirmation}
          cancelHandler={() => setShowSwitchConfirmation(false)}
          cancelButtonLabel="No"
          confirmHandler={() => {
            setShowSwitchConfirmation(false);
            handleSliderChange(MIN_PLANNED_USERS);
            setQuickMode(true);
          }}
          confirmButtonLabel="Yes"
          messageType="warning"
        >
          <p>
            Switching to this mode will reset AWS instance type and maximum users per instance as per minimum usage. However,
            untill you save this configuration, the current values will not be overwritten.
          </p>
          <p>Are you sure you want to switch?</p>
        </ModalConfirmation>
      </Modal>
    </>
  )
}

export function InstanceTypeMeter({
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
      {hourlyCostByCluster ? (
        <CenteredLevelItem title="Hourly Cluster Cost" starred={true}>
          ${hourlyCostByCluster.toFixed(4)}
        </CenteredLevelItem>
      ):(
        <CenteredLevelItem title="Hourly Cluster Cost" starred={true}>
          <LoadingMessage />
        </CenteredLevelItem>
      )}
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
        <Field
          required
          type="text"
          className="input"
          name="maxThreadsByInstance"
          data-testid="Max. Users / Instance"
          value={value}
          onChange={onChange}
          onFocus={(event: React.FocusEvent<HTMLInputElement>) => {
            event.target.setSelectionRange(0, event.target.value.length);
          }}
          {...{ disabled }} />
      </div>
    </div>
  )
}
