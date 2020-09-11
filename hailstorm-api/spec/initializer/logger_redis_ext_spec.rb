# frozen_string_literal: true

require 'spec_helper'
require 'initializer/redis_logger'
require 'hailstorm/support/log4j_backed_logger'

describe Hailstorm::Support::Log4jBackedLogger do
  it 'should publish log messages to Redis' do
    expect_any_instance_of(RedisLogger).to receive(:publish)
    require 'initializer/logger_redis_ext'
    logger = Hailstorm::Support::Log4jBackedLogger.get_logger('logger_redis_ext_spec')
    logger.debug('Test Message')
  end
end
