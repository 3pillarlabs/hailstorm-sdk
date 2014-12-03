class ChangeProjectStatusColoumnToInt < ActiveRecord::Migration
  def change
    change_column :projects, :status, :integer
  end
end
