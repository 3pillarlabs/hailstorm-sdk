# frozen_string_literal: true

require 'hailstorm/support/schema'

Hailstorm::Support::Schema.create_schema do |schema|
  schema.schema_tables.push(
    :project_configurations,
    :aws_ec2_prices
  )

  # Tables for API
  module ApiExtensions
    def create_project_configurations
      ActiveRecord::Migration.create_table(:project_configurations) do |t|
        t.references :project, null: false
        t.text :stringified_config, null: false
      end
    end

    def create_aws_ec2_prices
      ActiveRecord::Migration.create_table(:aws_ec2_prices) do |t|
        t.string    :region, null: false, unique: true
        t.text      :raw_data, null: false
        t.timestamp :next_update, null: false
      end
    end
  end

  schema.extend(ApiExtensions)
end
