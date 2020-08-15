require 'hailstorm/support'
require 'active_support/values/time_zone'
require 'active_record'
require 'hailstorm/behavior/loggable'

# Establish a database connection
class Hailstorm::Support::DbConnection
  include Hailstorm::Behavior::Loggable

  attr_reader :connection_spec

  # @param [Hash] connection_spec
  def self.establish!(connection_spec)
    self.new(connection_spec).establish
  end

  def initialize(connection_spec)
    @connection_spec = connection_spec.merge(properties: { serverTimezone: local_time_zone_id })
  end

  def establish
    ActiveRecord::Base.establish_connection(connection_spec) # this is lazy, does not fail!
    create_database_if_not_exists
  end

  private

  def local_time_zone_id
    local_time = Time.now
    tz = ActiveSupport::TimeZone.all.find { |tz| tz.utc_offset == local_time.utc_offset }
    tz.tzinfo.name
  end

  def create_database_if_not_exists
    test_connection!
  rescue ActiveRecord::ActiveRecordError
    logger.info 'Database does not exist, creating...'
    create_database
  end

  def test_connection!
    ActiveRecord::Base.connection.exec_query('select 1')
  end

  def create_database
    ActiveRecord::Base.establish_connection(connection_spec.merge(database: nil))
    ActiveRecord::Base.connection.create_database(connection_spec[:database])
    ActiveRecord::Base.establish_connection(connection_spec)
  end
end
