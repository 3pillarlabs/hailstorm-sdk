# frozen_string_literal: true

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/support/jmeter_installer'

# Validator for :custom_jmeter_installer_url
class Hailstorm::Model::JmeterInstallerUrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    validator_klass = Hailstorm::Support::JmeterInstaller::Validator
    return if validator_klass.validate_download_url_format(value)

    record.errors[attribute] << (options[:message] || "does not end with .tgz or .tar.gz: #{value}")
  end
end
