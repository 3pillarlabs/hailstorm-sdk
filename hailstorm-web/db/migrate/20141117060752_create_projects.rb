class CreateProjects < ActiveRecord::Migration
  def change
    create_table :projects do |t|
      t.string :title, :null => false, :unique => true
      t.boolean :status, :default=> 0, :null => false

      t.timestamps
    end
  end
end
