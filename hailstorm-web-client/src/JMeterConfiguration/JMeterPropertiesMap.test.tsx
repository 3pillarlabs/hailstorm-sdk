import { render } from '@testing-library/react';
import React from 'react';
import { PropertiesForm } from './JMeterPropertiesMap';

describe('<JMeterPropertiesMap />', () => {

  it('should change properties in form', () => {
    const {getByTestId, rerender} = render(<PropertiesForm
      onDisable={jest.fn()}
      onRemove={jest.fn()}
      onSubmit={jest.fn()}
      properties={[{key: "foo", value: "10"}]}
      fileId={1}
    />)

    const fooElement = getByTestId("foo");
    expect(fooElement.getAttribute("value")).toBe("10");

    rerender(<PropertiesForm
      onDisable={jest.fn()}
      onRemove={jest.fn()}
      onSubmit={jest.fn()}
      properties={[{key: "bar", value: "20"}]}
      fileId={1}
    />);

    const barElement = getByTestId("bar");
    expect(barElement.getAttribute("value")).toBe("20");
  });
});
