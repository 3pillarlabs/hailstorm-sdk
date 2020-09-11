# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'active_record/base'
require 'active_record/errors'

require 'hailstorm/behavior/loggable'
require 'hailstorm/support/db_connection'

# Creates the configured database as per current configuration in <code>config/database.yml</code>.
class DbConfig
  include Hailstorm::Behavior::Loggable

  def self.initialize
    ActiveRecord::Base.logger = logger
    db_props_template = ERB.new(File.read(File.expand_path('../../../config/database.yml', __FILE__)))
    database_properties = YAML.load(db_props_template.result)
    connection_spec = database_properties[Hailstorm.env.to_s]
    connection_spec.symbolize_keys!
    connection_spec[:pool] = 50
    connection_spec[:wait_timeout] = 30.minutes
    Hailstorm::Support::DbConnection.establish!(connection_spec)
    at_exit { ActiveRecord::Base.connection.disconnect! if ActiveRecord::Base.connected? }
  end
end

DbConfig.initialize
