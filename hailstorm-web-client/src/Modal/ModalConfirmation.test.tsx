import { render } from '@testing-library/react';
import React from 'react';
import { ModalConfirmation } from "./ModalConfirmation";

describe('ModalConfirmation', () => {
  it('should render successfully with required attributes', () => {
    const {queryByText} = render(
      <ModalConfirmation
        isActive={true}
        cancelHandler={jest.fn()}
        confirmHandler={jest.fn()}
      >
        <div>
          <strong>Would you like to continue?</strong>
        </div>
      </ModalConfirmation>
    );

    expect(queryByText(/OK/i)).not.toBeNull();
    expect(queryByText('Would you like to continue?')).not.toBeNull();
  });

  it('should render successfully with all attributes', () => {
    const {queryByText} = render(
      <ModalConfirmation
        isActive={true}
        cancelHandler={jest.fn()}
        confirmHandler={jest.fn()}
        cancelButtonLabel="No"
        classModifiers="modal"
        confirmButtonLabel="Yes"
        isConfirmDisabled={false}
        messageType="warning"
      >
        <div>
          <strong>Would you like to continue?</strong>
        </div>
      </ModalConfirmation>
    );

    expect(queryByText('Yes')).not.toBeNull();
    expect(queryByText('No')).not.toBeNull();
    expect(queryByText('Would you like to continue?')).not.toBeNull();
  });
});
