class RemoveUniqueIndexFromProject < ActiveRecord::Migration
  def change
    remove_index :projects, column: :title
  end
end
