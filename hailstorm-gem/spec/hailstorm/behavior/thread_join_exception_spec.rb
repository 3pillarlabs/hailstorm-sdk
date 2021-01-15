# frozen_string_literal: true

require 'spec_helper'

require 'hailstorm/behavior/thread_join_exception'

describe Hailstorm::ThreadJoinException do
  context 'on single exception' do
    context "when exception is other than #{described_class}" do
      it 'should wrap the exception in a collection' do
        error = StandardError.new('mock error')
        thread_exception = described_class.new(error)
        expect(thread_exception.exceptions.first).to eql(error)
      end
    end

    context "when exception is #{described_class}" do
      it "should wrap the exception's exceptions collection" do
        error = StandardError.new('mock error')
        thread_exception1 = described_class.new(error)
        thread_exception2 = described_class.new(thread_exception1)
        expect(thread_exception2.exceptions.first).to eql(error)
      end
    end
  end

  context 'on multiple exceptions' do
    context "when none of the exceptions is #{described_class}" do
      it 'should wrap the exceptions in a collections' do
        error1 = StandardError.new('mock error 1')
        error2 = StandardError.new('mock error 2')
        thread_exception = described_class.new([error1, error2])
        expect(thread_exception.exceptions).to eql([error1, error2])
      end
    end

    context "when one or more of the exceptions are #{described_class}" do
      it 'should wrap the exceptions in a flat collection' do
        error1 = StandardError.new('mock error 1')
        error2 = StandardError.new('mock error 2')
        error3 = StandardError.new('mock error 3')
        thread_exception2 = described_class.new([error1, error2])
        thread_exception2 = described_class.new([thread_exception2, error3])
        thread_exception3 = described_class.new(thread_exception2)
        expect(thread_exception3.exceptions).to eql([error1, error2, error3])
      end
    end
  end

  context 'when all exceptions are retryable' do
    it 'should indicate that the thread exception can be retried' do
      error1 = Hailstorm::AgentCreationFailure.new('mock error 1')
      error2 = Hailstorm::AgentCreationFailure.new('mock error 2')
      thread_exception = described_class.new([error1, error2])
      expect(thread_exception).to be_retryable
    end
  end

  context 'when one or more exceptions are not retryable' do
    it 'should indicate that the thread exception can not be retried' do
      error1 = Hailstorm::AgentCreationFailure.new('mock error 1')
      error2 = Hailstorm::DataCenterJavaFailure.new('mock error 2')
      thread_exception = described_class.new([error1, error2])
      expect(thread_exception).to_not be_retryable
    end
  end
end
