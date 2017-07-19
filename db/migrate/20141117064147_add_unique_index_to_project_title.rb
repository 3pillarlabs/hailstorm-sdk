class AddUniqueIndexToProjectTitle < ActiveRecord::Migration
  def change
    add_index :projects, :title, :unique => true
  end
end
