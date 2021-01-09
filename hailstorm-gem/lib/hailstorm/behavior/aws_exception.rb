# frozen_string_literal: true

require 'hailstorm/exceptions'

# Hailstorm Aws Exception wrapper
class Hailstorm::AwsException < Hailstorm::Exception
  attr_accessor :data
end
