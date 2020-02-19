require 'initializer/redis_logger'
require 'hailstorm/support/log4j_backed_logger'

return if Hailstorm.env == :test

$redis = RedisLogger.new

class Hailstorm::Support::Log4jBackedLogger

  alias :original_log_message :log_message

  def log_message(log_method_sym, msg)
    original_log_message(log_method_sym, msg)
    $redis.publish(priority: self.class.logger_levels.find_index(log_method_sym), level: log_method_sym, message: msg)
  end
end
