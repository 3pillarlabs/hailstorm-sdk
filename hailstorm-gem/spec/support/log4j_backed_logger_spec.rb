require 'spec_helper'
require 'hailstorm/support/log4j_backed_logger'

describe Hailstorm::Support::Log4jBackedLogger do

  it 'should emit a fatal message' do
    logger = Hailstorm::Support::Log4jBackedLogger.get_logger(__FILE__)
    logger.should_receive(:log_message).with(:fatal, kind_of(String)).exactly(2).times
    logger.fatal('sample fatal message') if logger.fatal?
    logger.fatal { 'another message' }
  end

  context '#add' do
    it 'should log the message' do
      logger = Hailstorm::Support::Log4jBackedLogger.get_logger(__FILE__)
      logger.instance_variable_get('@log4j_logger').stub!(:isEnabledFor).and_return(true)
      logger.should_receive(:log_message).exactly(7 ).times
      [Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR, Logger::FATAL].each do |level|
        logger.add(level) { 'sample message' }
      end

      logger.add(Logger::INFO, 'sample message')
      logger.add(999, nil, 'Net::SSH')
    end
  end
end
