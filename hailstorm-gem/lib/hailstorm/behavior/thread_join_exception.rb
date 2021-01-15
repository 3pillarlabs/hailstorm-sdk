# frozen_string_literal: true

require 'hailstorm/exceptions'

# Exception for threading issues. This is a composite exception. It wraps a collection of exceptions.
# This collection is guaranteed to be a flat collection, even in the case of multiple levels of bubbled
# exceptions on joining threads.
class Hailstorm::ThreadJoinException < Hailstorm::Exception

  attr_reader :exceptions

  # @param [Array|Exception] exception_or_ary
  def initialize(exception_or_ary = [])
    super

    @exceptions = exception_or_ary.is_a?(Array) ? flat_unwrap(exception_or_ary) : unwrap(exception_or_ary)
  end

  def message
    @message ||= self.exceptions.empty? ? super.message : self.exceptions.collect(&:message).join("\n")
  end

  def retryable?
    self.exceptions.all?(&:retryable?)
  end

  private

  # @param [Exception] exception
  def unwrap(exception)
    exception.is_a?(self.class) ? exception.exceptions : [exception]
  end

  # @param [Array<Exception>] exceptions
  def flat_unwrap(exceptions)
    exceptions.flat_map { |exception| unwrap(exception) }
  end
end
