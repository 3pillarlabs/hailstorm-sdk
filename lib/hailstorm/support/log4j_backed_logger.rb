# Log4j backed logger
# @author Sayantam Dey

require 'hailstorm/support'

class Hailstorm::Support::Log4jBackedLogger

  def self.get_logger(klass)
    self.new(backing_logger_impl.getLogger(klass.name))
  end

  def initialize(log4j_logger)
    @log4j_logger = log4j_logger
  end

  def debug?
    @log4j_logger.isEnabledFor(logger_level_impl::DEBUG)
  end

  def debug(msg = nil, &block)
    if block_given?
      log_message(:debug, block.call) if debug?
    else
      log_message(:debug, msg)
    end
  end

  def info?
    @log4j_logger.isEnabledFor(logger_level_impl::INFO)
  end

  def info(msg = nil, &block)
    if block_given?
      log_message(:info, block.call) if info?
    else
      log_message(:info, msg)
    end
  end

  def warn?
    @log4j_logger.isEnabledFor(logger_level_impl::WARN)
  end

  def warn(msg = nil, &block)
    if block_given?
      log_message(:warn, block.call) if warn?
    else
      log_message(:warn, msg)
    end
  end

  def error?
    @log4j_logger.isEnabledFor(logger_level_impl::ERROR)
  end

  def error(msg = nil, &block)
    if block_given?
      log_message(:warn, block.call) if error?
    else
      log_message(:error, msg)
    end
  end

  def fatal?
    @log4j_logger.isEnabledFor(logger_level_impl::FATAL)
  end

  def fatal(msg = nil, &block)
    if block_given?
      log_message(:fatal, block.call) if fatal?
    else
      log_message(:fatal, msg)
    end
  end

  def add(severity, message = nil, progname = nil, &block)

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
    if @log4j_logger.isEnabledFor(log4j_severity)
      if message.nil?
        if block_given?
          message = block.call()
        else
          message = progname
        end
      end
      log_message(log_method_sym, message)
    end
  end

  def log_message(log_method_sym, msg)
    logger_message = nil
    if msg.nil? or not msg.is_a?(String)
      logger_message = msg.inspect
    else
      logger_message = msg
    end
    logger_message.chomp! unless logger_message.frozen?
    with_context { @log4j_logger.send(log_method_sym, logger_message) }
  end

  def with_context
    logger_mdc_impl.put("caller", caller(3).first)
    begin
      yield
    ensure
      logger_mdc_impl.remove("caller")
    end
  end

  def self.backing_logger_impl()
    org.apache.log4j.Logger
  end

  def logger_level_impl()
    org.apache.log4j.Level
  end

  def logger_mdc_impl()
    org.apache.log4j.MDC
  end

  def method_missing(method_name, *args, &block)
    self.warn { "#{method_name}: Undefined method -- call stack:\n#{caller.join("\n")}" }
  end

end

