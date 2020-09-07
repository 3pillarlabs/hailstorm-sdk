# frozen_string_literal: true

require 'hailstorm/support'
require 'hailstorm/exceptions'

# Wait methods
module Hailstorm::Support::Waiter

  # Seconds between successive EC2 status checks
  DOZE_TIME = 5

  # Waits for <tt>timeout_sec</tt> seconds for condition in <tt>block</tt>
  # to evaluate to true, else throws an error.
  # @param [String] message
  # @param [Integer] timeout_sec
  # @param [Integer] sleep_duration
  # @param [Hash] err_attrs attributes to add to error message in case of timeout
  # @return [Object] result of the block
  # @raise [Hailstorm::Exception] if block does not return true within timeout_sec
  def wait_for(message = nil, timeout_sec: 300, sleep_duration: DOZE_TIME, err_attrs: {}, &_block)
    # make the timeout configurable by an environment variable
    timeout_sec = ENV['HAILSTORM_EC2_TIMEOUT_OVERRIDE'] || timeout_sec
    total_elapsed = 0
    while total_elapsed <= timeout_sec
      before_yield_time = Time.now.to_i
      result = yield
      return result if result

      sleep(sleep_duration)
      total_elapsed += (Time.now.to_i - before_yield_time)
    end
    raise(Hailstorm::Exception, "Timeout while waiting #{message ? "for #{message}" : ''}: #{err_attrs}.")
  end
end
