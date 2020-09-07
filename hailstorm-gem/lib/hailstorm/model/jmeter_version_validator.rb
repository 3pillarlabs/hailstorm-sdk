# frozen_string_literal: true

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/support/jmeter_installer'

# Validator for jmeter_url
class Hailstorm::Model::JmeterVersionValidator < ActiveModel::EachValidator

  MIN_MAJOR = 2
  MIN_MINOR = 6

  def validate_each(record, attribute, value)
    validator_klass = Hailstorm::Support::JmeterInstaller::Validator
    return if validator_klass.validate_version(value, MIN_MAJOR, MIN_MINOR)

    record.errors[attribute] << (options[:message] || "must be #{MIN_MAJOR}.#{MIN_MINOR} or higher")
  end
end
