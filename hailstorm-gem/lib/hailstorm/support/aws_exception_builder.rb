# frozen_string_literal: true

require 'hailstorm/support'
require 'hailstorm/behavior/aws_exception'

# Hailstorm::AwsException builder
module Hailstorm::Support::AwsExceptionBuilder
  # @param [Aws::Errors::ServiceError] aws_error
  def self.from(aws_error)
    exception = Hailstorm::AwsException.new(aws_error.message)
    exception.retryable = aws_error.retryable?
    exception.data = aws_error.data
    exception.code = aws_error.code
    exception.context = aws_error.context
    exception
  end
end
