class ChangeProjectResultDownload < ActiveRecord::Migration
  def change
    change_column :project_result_downloads, :test_ids, :string
  end
end
