require 'hailstorm/support'
require 'hailstorm/behavior/loggable'

# Wrapper class providing convenient access and application specific handling
# @author Sayantam Dey
class Hailstorm::Support::Thread

  include Hailstorm::Behavior::Loggable

  # Start a new Ruby thread. The thread is push to Hailstorm.application.threads
  # so they can be joined on later. *args are passed as thread local variables
  # to the newly created thread.
  # @param [Object] *args
  # @return [Thread] the thread object
  def self.start(*args)
    Hailstorm.logger.debug { "#{self}.#{__method__}" }
    if Hailstorm.application.multi_threaded?
      thread = Thread.start(args) do |args|
        begin
          yield(*args)
        rescue Object => e
          logger.error(e.message)
          logger.debug { "\n".concat(e.backtrace.join("\n")) }
          raise
        ensure
          ActiveRecord::Base.connection.close
        end
      end
      Thread.current[:spawned] ||= []
      Thread.current[:spawned].push(thread)

      return thread
    else
      yield(*args)
    end
  end

  # Joins all threads spawned by current thread and clears active connections.
  # @raise [Hailstorm::Exception] if not all threads finished gracefully.
  def self.join
    Hailstorm.logger.debug { "#{self}.#{__method__}" }
    # Give up the current threads connection, so that a child thread waiting
    # on it will get the connection
    ActiveRecord::Base.connection_pool.release_connection
    thread_exceptions = []
    spawned = Thread.current[:spawned]
    until spawned.blank?
      t = spawned.shift
      begin
        t.join
      rescue Object => e
        thread_exceptions.push(e)
      end
    end

    raise Hailstorm::ThreadJoinException, thread_exceptions unless thread_exceptions.empty?
  end
end
