require 'initializer/redis_logger'
require 'hailstorm/support/log4j_backed_logger'

return if Hailstorm.env == :test

$redis = RedisLogger.new

class Hailstorm::Support::Log4jBackedLogger

  # @param [Symbol] log_level
  # @param [String] message
  def extended_logging(log_level, message)
    caller = logger_mdc_impl.get('caller')
    filters = [
      caller =~ /active_support/ && log_level == :debug,
      caller =~ /aws-sdk/ && %i[debug info].include?(log_level),
      caller =~ /net-ssh/ && %i[debug info].include?(log_level)
    ]

    return if filters.include?(true)

    $redis.publish(priority: self.class.logger_levels.find_index(log_level), level: log_level, message: message)
  end
end
