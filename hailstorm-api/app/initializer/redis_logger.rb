require 'redis'
require 'json'

class RedisLogger

  BREAK_FOR = 10

  CHANNEL = 'hailstorm-logs'

  # @return [Redis]
  attr_reader :redis

  # @param [Integer]
  attr_accessor :skip_message_count

  def initialize(redis_client: nil, break_for: nil)
    @redis = redis_client || Redis.new
    @break_for = break_for || BREAK_FOR
    self.skip_message_count = 0
  end

  # @param [Integer] priority
  # @param [Symbol] level
  # @param [String] message
  def publish(priority:, level:, message:)
    log_event = {
      timestamp: Time.now.to_i,
      priority: priority,
      level: level,
      message: message
    }

    begin
      if self.skip_message_count == 0
        self.redis.publish(CHANNEL, JSON.dump(log_event))
      else
        self.skip_message_count -= 1
      end
    rescue Redis::BaseError => redis_error
      self.skip_message_count = @break_for - 1
      puts "[WARN] #{redis_error.message}"
    end
  end
end
