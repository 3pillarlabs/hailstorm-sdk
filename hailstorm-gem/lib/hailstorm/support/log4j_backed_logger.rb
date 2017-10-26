require 'hailstorm/support'

# Log4j backed logger
# @author Sayantam Dey
class Hailstorm::Support::Log4jBackedLogger

  def self.get_logger(klass_or_name)
    self.new(backing_logger_impl.getLogger(klass_or_name.respond_to?(:name) ? klass_or_name.name : klass_or_name.to_s))
  end

  def initialize(log4j_logger)
    @log4j_logger = log4j_logger
  end

  def debug?
    @log4j_logger.isEnabledFor(logger_level_impl::DEBUG)
  end

  def debug(msg = nil)
    if block_given?
      log_message(:debug, yield) if debug?
    else
      log_message(:debug, msg)
    end
  end

  def info?
    @log4j_logger.isEnabledFor(logger_level_impl::INFO)
  end

  def info(msg = nil)
    if block_given?
      log_message(:info, yield) if info?
    else
      log_message(:info, msg)
    end
  end

  def warn?
    @log4j_logger.isEnabledFor(logger_level_impl::WARN)
  end

  def warn(msg = nil)
    if block_given?
      log_message(:warn, yield) if warn?
    else
      log_message(:warn, msg)
    end
  end

  def error?
    @log4j_logger.isEnabledFor(logger_level_impl::ERROR)
  end

  def error(msg = nil)
    if block_given?
      log_message(:warn, yield) if error?
    else
      log_message(:error, msg)
    end
  end

  def fatal?
    @log4j_logger.isEnabledFor(logger_level_impl::FATAL)
  end

  def fatal(msg = nil)
    if block_given?
      log_message(:fatal, yield) if fatal?
    else
      log_message(:fatal, msg)
    end
  end

  def add(severity, message = nil, progname = nil)
    # map the severity & log_method
    log4j_severity,
    log_method_sym = case severity
                     when Logger::DEBUG
                       [logger_level_impl::DEBUG, :debug]
                     when Logger::INFO
                       [logger_level_impl::INFO, :info]
                     when Logger::WARN
                       [logger_level_impl::WARN, :warn]
                     when Logger::ERROR
                       [logger_level_impl::ERROR, :error]
                     when Logger::FATAL
                       [logger_level_impl::FATAL, :fatal]
                     else
                       [logger_level_impl::DEBUG, :debug]
                     end
    return unless @log4j_logger.isEnabledFor(log4j_severity)
    if message.nil?
      message = if block_given?
                  yield
                else
                  progname
                end
    end
    log_message(log_method_sym, message)
  end

  def log_message(log_method_sym, msg)
    logger_message = if msg.nil? || !msg.is_a?(String)
                       msg.inspect
                     else
                       msg
                     end
    logger_message.chomp! unless logger_message.frozen?
    with_context { @log4j_logger.send(log_method_sym, logger_message) }
  end

  def with_context
    logger_mdc_impl.put('caller', caller(3).first)
    begin
      yield
    ensure
      logger_mdc_impl.remove('caller')
    end
  end

  def self.backing_logger_impl
    org.apache.log4j.Logger
  end

  def logger_level_impl
    org.apache.log4j.Level
  end

  def logger_mdc_impl
    org.apache.log4j.MDC
  end

  def method_missing(method_name, *_args)
    self.warn { "#{method_name}: Undefined method -- call stack:\n#{caller.join("\n")}" }
    super
  end

  def respond_to_missing?(*)
    super
  end

end
