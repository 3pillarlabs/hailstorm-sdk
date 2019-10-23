import React, { useState, useEffect } from 'react';
import { NonLinearSlider } from './NonLinearSlider';
import { lowestCostOption, computeChoice, maxThreadsByCluster } from './AWSInstanceCalculator';
import { AWSInstanceChoiceOption } from './domain';
import { Loader } from '../Loader/Loader';

const MIN_VALUE = 50;

export function AWSInstanceChoice({
  regionCode,
  onChange,
  fetchPricing,
  setHourlyCostByCluster
}: {
  regionCode: string;
  onChange: (choice: AWSInstanceChoiceOption) => void;
  fetchPricing: (regionCode: string) => Promise<AWSInstanceChoiceOption[]>;
  setHourlyCostByCluster?: React.Dispatch<React.SetStateAction<number | undefined>>;
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
        <p className="card-header-title">
          AWS Instance{quickMode ? ' Advisor': ''}
        </p>
        <a
          className="card-header-icon is-size-7"
          onClick={() => {
            if (quickMode) {
              setHourlyCostByCluster && setHourlyCostByCluster(undefined);
            } else {
              handleSliderChange(MIN_VALUE);
            }

            setQuickMode(!quickMode);
          }}
        >
          {quickMode ? 'Advanced ' : 'Quick '}Mode
        </a>
      </div>
      <div className="card-content">
        {quickMode ? (
        <>
        <div className="field">
          <div className="control">
            <NonLinearSlider
              initialValue={MIN_VALUE}
              onChange={handleSliderChange}
              step={50}
              maximum={maxThreadsByCluster(pricingData)}
              minimum={MIN_VALUE}
            />
          </div>
        </div>
        <hr/>
        <div className="level">
          <div className="level-item has-text-centered">
            <div>
              <p className="heading">AWS Instance Type *</p>
              <p className="title" data-testid="AWS Instance Type">{instanceType}</p>
            </div>
          </div>
          <div className="level-item has-text-centered">
            <div>
              <p className="heading">Max. Users / Instance *</p>
              <p className="title" data-testid="Max. Users / Instance">{maxThreadsByInstance}</p>
            </div>
          </div>
          <div className="level-item has-text-centered">
            <div>
              <p className="heading"># Instances</p>
              <p className="title">{numInstances}</p>
            </div>
          </div>
        </div>
        </>
        ) : (
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
              onChange={(event: {target: {value: string}}) => {
                setInstanceType(event.target.value);
                onChange(new AWSInstanceChoiceOption({
                  instanceType: event.target.value,
                  maxThreadsByInstance
                }));
              }}
            />
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
              onChange={(event: {target: {value: string}}) => {
                setMaxThreadsByInstance(parseInt(event.target.value));
                onChange(new AWSInstanceChoiceOption({
                  maxThreadsByInstance: parseInt(event.target.value),
                  instanceType
                }));
              }}
            />
          </div>
        </div>
        </>
        )}
      </div>
    </div>
  )
}
