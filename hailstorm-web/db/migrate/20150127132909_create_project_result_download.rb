class CreateProjectResultDownload < ActiveRecord::Migration
  def change
    create_table :project_result_downloads do |t|
      t.integer :test_ids
      t.integer :project_id
      t.integer :status, :default=> 0, :null => false
      t.string  :result_type

      t.timestamps
    end
  end
end
