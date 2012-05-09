# Wrapper class providing convenient access and application specific handling
# @author Sayantam Dey

require 'hailstorm/support'

class Hailstorm::Support::Thread
  
  # Start a new Ruby thread. The thread is push to Hailstorm.application.threads
  # so they can be joined on later. *args are passed as thread local variables
  # to the newly created thread.
  # @param [Object] *args
  # @return [Thread] the thread object  
  def self.start(*args, &block)
    
    Hailstorm.logger.debug { "#{self}.#{__method__}" }
    simulate = false # for debugging purpose
    unless simulate
      thread = Thread.start(args) do |args|
        Thread.current[:connection] = ActiveRecord::Base.connection
        yield(*args)
      end
      Thread.current[:spawned] ||= []
      Thread.current[:spawned].push(thread)
      
      return thread
    else
      yield(*args)
    end 
  end
  
  # Joins all threads spawned by current thread and clears active connections.
  def self.join()
    
    Hailstorm.logger.debug { "#{self}.#{__method__}" }
    spawned = Thread.current[:spawned]
    until spawned.blank?
      t = spawned.shift()
      begin
        t.join()
      rescue StandardError => e
        logger.warn(e.message())
        logger.debug { "\n".concat(e.backtrace().join("\n")) }
      ensure
        t[:connection].close() unless t[:connection].nil? 
      end
    end
  end
  
  
end
