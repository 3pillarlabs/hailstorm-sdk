# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/support/log4j_backed_logger'

describe Hailstorm::Support::Log4jBackedLogger do
  it 'should emit a fatal message' do
    logger = Hailstorm::Support::Log4jBackedLogger.get_logger(__FILE__)
    expect(logger).to receive(:log_message).with(:fatal, kind_of(String)).exactly(2).times
    logger.fatal('sample fatal message') if logger.fatal?
    logger.fatal { 'another message' }
  end

  context '#add' do
    it 'should log the message' do
      logger = Hailstorm::Support::Log4jBackedLogger.get_logger(__FILE__)
      allow(logger.instance_variable_get('@log4j_logger')).to receive(:isEnabledFor).and_return(true)
      expect(logger).to receive(:log_message).exactly(7).times
      [Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR, Logger::FATAL].each do |level|
        logger.add(level) { 'sample message' }
      end

      logger.add(Logger::INFO, 'sample message')
      logger.add(999, nil, 'Net::SSH')
    end
  end

  context 'return values' do
    before(:each) do
      @logger = Hailstorm::Support::Log4jBackedLogger.get_logger(__FILE__)
    end

    context '#debug' do
      it 'should return nil' do
        expect(@logger.debug('foo')).to be_nil
        expect(@logger.debug { 'foo' }).to be_nil
      end
    end

    context '#info' do
      it 'should return nil' do
        expect(@logger.info('foo')).to be_nil
        expect(@logger.info { 'foo' }).to be_nil
      end
    end

    context '#warn' do
      it 'should return nil' do
        expect(@logger.warn('foo')).to be_nil
        expect(@logger.warn { 'foo' }).to be_nil
      end
    end

    context '#error' do
      it 'should return nil' do
        expect(@logger.error('foo')).to be_nil
        expect(@logger.error { 'foo' }).to be_nil
      end
    end

    context '#fatal' do
      it 'should return nil' do
        expect(@logger.fatal('foo')).to be_nil
        expect(@logger.fatal { 'foo' }).to be_nil
      end
    end
  end
end
