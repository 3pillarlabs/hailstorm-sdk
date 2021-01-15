# frozen_string_literal: true

require 'spec_helper'

describe Hailstorm::Exception do
  it 'should not be retryable' do
    expect(Hailstorm::Exception.new('mock error 1')).to_not be_retryable
  end

  context 'when diagnostic aware' do
    it 'should respond to #diagnostics' do
      exception = Hailstorm::DiagnosticAwareException.new
      expect(exception).to respond_to(:diagnostics)
    end
  end

  context Hailstorm::DataCenterAccessFailure do
    it 'should be retryable' do
      exception = Hailstorm::DataCenterAccessFailure.new('root', [], 'hailstorm.pem')
      expect(exception).to be_retryable
    end
  end

  context Hailstorm::JavaInstallationException do
    it 'should be retryable' do
      exception = Hailstorm::JavaInstallationException.new('us-east-1', 'mock error')
      expect(exception).to be_retryable
    end
  end
end
