# frozen_string_literal: true

require 'spec_helper'
require 'initializer/redis_logger'

describe RedisLogger do
  before(:each) do
    @mock_redis = instance_double(Redis)
    @redis_logger = RedisLogger.new(redis_client: @mock_redis, break_for: 3)
  end

  it 'should publish a message' do
    log_params = { priority: 1, level: :debug, message: 'test message' }
    expect(@mock_redis).to receive(:publish) do |channel, log_event_str|
      expect(channel).to be_a(String)
      log_event = JSON.parse(log_event_str).symbolize_keys
      expect(log_event[:timestamp]).to be_a(Integer)
      expect(log_params.slice(:priority, :level, :message)).to eq(log_params)
    end

    @redis_logger.publish(log_params)
  end

  context 'when a message publish fails due to a redis error' do
    before(:each) do
      allow(@mock_redis).to receive(:publish) { raise(Redis::BaseError, 'mock redis client error') }
    end

    it 'should not send the next set of messages' do
      expect(@mock_redis).to receive(:publish).once
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
    end

    it 'should send the message after threshold' do
      expect(@mock_redis).to receive(:publish).twice
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      allow(@mock_redis).to receive(:publish) { nil }
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
    end
  end

  context 'when a message publish fails due to a runtime error' do
    it 'should ignore the error' do
      allow(@mock_redis).to receive(:publish).and_raise(Encoding::UndefinedConversionError,
                                                        '"\xC4" from ASCII-8BIT to UTF-8')
      expect(@mock_redis).to receive(:publish).once
      expect { @redis_logger.publish(priority: 1, level: :info, message: 'message 1') }.to_not raise_error
    end
  end
end
