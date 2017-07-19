class CreateTargetHosts < ActiveRecord::Migration
  def change
    create_table :target_hosts do |t|
      t.references :project, index: true, :null => false
      t.string :host_name, :null => false
      t.string :type, :null => false, :default=> "nmon"
      t.string :role_name, :null => false
      t.string :executable_path
      t.integer :executable_pid
      t.string :user_name
      t.integer :sampling_interval, :null => false, :default=> 10

      t.timestamps
    end
  end
end
