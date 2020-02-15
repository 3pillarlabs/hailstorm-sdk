require 'hailstorm/support/schema'

Hailstorm::Support::Schema.create_schema do |schema|
  schema.schema_tables.push(:project_configurations)

  module ApiExtensions
    def create_project_configurations
      ActiveRecord::Migration.create_table(:project_configurations) do |t|
        t.references :project, null: false
        t.text :stringified_config, null: false
      end
    end
  end

  schema.extend(ApiExtensions)
end
