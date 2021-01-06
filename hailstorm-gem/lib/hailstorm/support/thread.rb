# frozen_string_literal: true

require 'hailstorm/support'
require 'hailstorm/behavior/loggable'
require 'hailstorm/exceptions'

# Wrapper class providing convenient access and application specific handling
# @author Sayantam Dey
class Hailstorm::Support::Thread

  include Hailstorm::Behavior::Loggable

  # :nocov:
  # Start a new Ruby thread. args are passed as thread local variables to the newly created thread.
  # @param [Array] args
  # @return [Thread] the thread object
  def self.start(*args)
    logger.debug { "#{self}.#{__method__}" }
    thread = Thread.start(args) do |thread_args|
      yield(*thread_args)
    rescue Object => e
      logger.error(e.message) unless e.is_a?(Hailstorm::Exception)
      logger.debug { e.backtrace.prepend("\n").join("\n") }
      raise
    ensure
      ActiveRecord::Base.connection.close
    end
    Thread.current[:spawned] ||= []
    Thread.current[:spawned].push(thread)

    thread
  end
  # :nocov:

  # Joins all threads spawned by current thread and clears active connections.
  # @raise [Hailstorm::Exception] if not all threads finished gracefully.
  def self.join
    logger.debug { "#{self}.#{__method__}" }
    # Give up the current threads connection, so that a child thread waiting
    # on it will get the connection
    ActiveRecord::Base.connection_pool.release_connection
    thread_exceptions = []
    spawned = Thread.current[:spawned]
    until spawned.blank?
      # :nocov:
      t = spawned.shift
      begin
        t.join
      rescue Object => e
        thread_exceptions.push(e)
      end
      # :nocov:
    end

    raise Hailstorm::ThreadJoinException, thread_exceptions unless thread_exceptions.empty?
  end
end
