require 'spec_helper'
require 'initializer/redis_logger'

describe RedisLogger do
  before(:each) do
    @mock_redis = mock(Redis)
    @redis_logger = RedisLogger.new(redis_client: @mock_redis, break_for: 3)
  end

  it 'should publish a message' do
    log_params = {priority: 1, level: :debug, message: 'test message'}
    @mock_redis.should_receive(:publish) do |channel, log_event_str|
      expect(channel).to be_a(String)
      log_event = JSON.parse(log_event_str).symbolize_keys
      expect(log_event[:timestamp]).to be_a(Integer)
      expect(log_params.slice(:priority, :level, :message)).to eq(log_params)
    end

    @redis_logger.publish(log_params)
  end
  
  context 'when a message publish fails' do
    before(:each) do
      @mock_redis.stub!(:publish).and_raise(Redis::BaseError, 'mock redis client error')
    end

    it 'should not send the next set of messages' do
      @mock_redis.should_receive(:publish).once
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
    end

    it 'should send the message after threshold' do
      @mock_redis.should_receive(:publish).twice
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
      @mock_redis.unstub!(:publish)
      @mock_redis.stub!(:publish)
      @redis_logger.publish(priority: 1, level: :info, message: 'message 1')
    end
  end
end
