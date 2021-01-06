# frozen_string_literal: true

require 'hailstorm/exceptions'

class Hailstorm::AwsException < Hailstorm::Exception
  include Hailstorm::TemporaryFailure

  attr_writer :retryable, :data

  # @param [Aws::Errors::ServiceError] aws_error
  def self.from(aws_error)
    exception = self.new(aws_error.message)
    exception.retryable = aws_error.retryable?
    exception
  end

  def initialize(msg = nil)
    super
    @retryable = false
  end

  def retryable?
    @retryable
  end
end
