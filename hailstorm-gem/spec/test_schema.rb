# frozen_string_literal: true

require 'hailstorm/support/schema'

# Additional schema for tests
class Hailstorm::Support::Schema

  alias dev_schema_tables schema_tables

  def schema_tables
    @test_schema_tables ||= dev_schema_tables.push(:test_clusters) # rubocop: disable Naming/MemoizedInstanceVariableName
  end

  # :nocov:

  def create_test_clusters
    ActiveRecord::Migration.create_table(:test_clusters) do |t|
      t.references  :project, null: false
      t.string      :name
      t.boolean     :active, null: false, default: false
      t.string      :user_name, null: false
    end
  end

  # :nocov:
end
