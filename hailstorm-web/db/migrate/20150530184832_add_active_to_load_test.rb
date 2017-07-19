class AddActiveToLoadTest < ActiveRecord::Migration
  def change
    add_column :load_tests, :active, :boolean, default: true
  end
end
