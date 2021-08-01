import React, { useState } from 'react';
import { ErrorMessage, Field } from "formik";
import { ReadOnlyField } from "./ReadOnlyField";
import { AWSInstanceChoice } from './AWSInstanceChoice';
import { AWSInstanceChoiceOption } from './domain';
import { ApiFactory } from '../api';

export function AWSFormField({
  labelText,
  fieldName,
  required,
  disabled,
  staticField,
  fieldValue
}:{
  labelText: string;
  fieldName?: string;
  required?: boolean;
  disabled?: boolean;
  staticField?: boolean;
  fieldValue?: any;
}) {
  if (!!staticField) {
    return (
      <ReadOnlyField label={labelText} value={fieldValue} />
    )
  }

  const label = required ? `${labelText} *` : labelText;
  return (
    <div className="field">
      <label className="label">{label}</label>
      <div className="control">
        <Field {...{required, disabled}} name={fieldName} className="input" type="text" data-testid={labelText} />
      </div>
      <ErrorMessage name="accessKey" render={(message) => (<p className="help is-danger">{message}</p>)} />
    </div>
  );
}

export function AWSInstanceChoiceField({
  awsRegion,
  maxThreadsByInstance,
  setSelectedInstanceType,
  instanceType,
  disabled,
  onChange
}: {
  awsRegion: string;
  setSelectedInstanceType: React.Dispatch<React.SetStateAction<AWSInstanceChoiceOption | undefined>>;
  instanceType?: string;
  maxThreadsByInstance?: number;
  disabled?: boolean;
  onChange?: () => void;
}) {
  const [hourlyCostByCluster, setHourlyCostByCluster] = useState<number>();
  const fetchPricing: (regionCode: string) => Promise<AWSInstanceChoiceOption[]> = (regionCode) => {
    return ApiFactory().awsInstancePricing().list(regionCode);
  };

  const handleAWSInstanceChange = (choice: AWSInstanceChoiceOption) => {
    setSelectedInstanceType(choice);
    if (choice.hourlyCostByInstance > 0) {
      setHourlyCostByCluster(choice.hourlyCostByCluster());
    }
    onChange && onChange();
  };

  return (
    <div className="field">
      <div className="control">
        <AWSInstanceChoice
          onChange={handleAWSInstanceChange}
          regionCode={awsRegion}
          savedMaxThreadsByInstance={maxThreadsByInstance}
          savedInstanceType={instanceType}
          {...{ fetchPricing, setHourlyCostByCluster, hourlyCostByCluster, disabled }}
        />
      </div>
    </div>

  );
}
