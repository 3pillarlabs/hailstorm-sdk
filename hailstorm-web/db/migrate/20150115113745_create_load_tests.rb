class CreateLoadTests < ActiveRecord::Migration
  def change
    create_table :load_tests do |t|
      t.integer :execution_cycle_id
      t.integer :project_id
      t.integer :total_threads_count
      t.float :avg_90_percentile
      t.float :avg_tps
      t.datetime :started_at
      t.datetime :stopped_at
    end
  end
end
