import React, { useState } from 'react';
import { mount } from 'enzyme';
import { fireEvent, render } from '@testing-library/react';
import { MachineSet } from './MachineSet';

describe('<MachineSet />', () => {
  const onChange = jest.fn();
  const mockSetMachines = jest.fn();

  function TestComponent({
    machines = [],
    setMachines,
    machineErrors,
    disabled
  }: {
    machines?: string[];
    setMachines?: React.Dispatch<React.SetStateAction<string[]>>;
    machineErrors?: {[K: string]: string};
    disabled?: boolean;
  }) {
    return (
      <MachineSet
        name="machines"
        {...{machines, machineErrors, disabled}}
        onChange={onChange.mockImplementation(setMachines || mockSetMachines)}
      />
    )
  }

  function EnclosingForm({
    machineErrors,
    disabled
  }: {
    machineErrors?: {[K: string]: string};
    disabled?: boolean;
  }) {
    const [machines, setMachines] = useState<string[]>([]);
    return (
      <TestComponent {...{machines, setMachines, machineErrors, disabled}} />
    )
  }

  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should render without crashing', () => {
    render(<TestComponent />);
  });

  it('should show two fields initially', () => {
    const { getAllByTestId } = render(<EnclosingForm />);
    const inputElements = getAllByTestId("dc-machine");
    expect(inputElements).toHaveLength(2);
  });

  it('should show another field when the last field has a value', async () => {
    const { getAllByTestId, findAllByTestId } = render(<EnclosingForm />);
    const inputElements = getAllByTestId("dc-machine");
    fireEvent.change(inputElements[0], {target: {value: 'a'}});
    fireEvent.change(inputElements[1], {target: {value: 'b'}});

    let updatedElements = await findAllByTestId("dc-machine");
    expect(updatedElements).toHaveLength(3);

    fireEvent.change(updatedElements[2], {target: {value: 'c'}});
    updatedElements = await findAllByTestId("dc-machine");
    expect(updatedElements).toHaveLength(4);
    expect(updatedElements[3].getAttribute("value")).toBeFalsy();
  });

  it('should remove extra field if last field value is empty', async () => {
    const { getAllByTestId, findAllByTestId } = render(<EnclosingForm />);
    const inputElements = getAllByTestId("dc-machine");
    fireEvent.change(inputElements[0], {target: {value: 'a'}});
    fireEvent.change(inputElements[1], {target: {value: 'b'}});
    fireEvent.change(inputElements[1], {target: {value: ''}});
    let updatedElements = await findAllByTestId("dc-machine");
    expect(updatedElements).toHaveLength(2);
  });

  it('should send back only fields with value', () => {
    const { getAllByTestId } = render( <EnclosingForm /> );
    const fields = getAllByTestId("dc-machine");
    fireEvent.change(fields[0], {target: {value: 'a'}});
    expect(onChange).toBeCalledWith(['a']);
  });

  it('should show errors associated with machines', () => {
    const { getAllByTestId, rerender, queryByText } = render( <EnclosingForm /> );
    const fields = getAllByTestId("dc-machine");
    fireEvent.change(fields[0], {target: {value: 'a'}});
    rerender( <EnclosingForm machineErrors={{ 'a': 'not reachable' }} /> );
    expect(queryByText("not reachable")).not.toBeNull();
  });

  it('should disable fields', () => {
    const { getAllByTestId } = render( <EnclosingForm disabled={true} /> );
    const fields = getAllByTestId("dc-machine");
    expect(fields[0].hasAttribute("disabled")).toBe(true);
    expect(fields[1]).toHaveProperty("disabled");
  });

  it('should always have two fields', () => {
    const { getAllByTestId } = render(<EnclosingForm />);
    const inputElements = getAllByTestId("dc-machine");
    fireEvent.change(inputElements[0], {target: {value: 'a'}});
    fireEvent.change(inputElements[0], {target: {value: ''}});
    expect(getAllByTestId("dc-machine")).toHaveLength(2);
  });

  it('should break up values with whitespace into multiple fields', () => {
    const { getAllByTestId } = render(<EnclosingForm />);
    const inputElements = getAllByTestId("dc-machine");
    fireEvent.change(inputElements[0], {target: {value: 'a b c d e'}});
    expect(getAllByTestId("dc-machine")).toHaveLength(6);
  });
});
