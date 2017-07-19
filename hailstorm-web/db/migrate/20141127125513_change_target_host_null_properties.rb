class ChangeTargetHostNullProperties < ActiveRecord::Migration
  def change
    change_column :target_hosts, :host_name, :string, :null => true
    change_column :target_hosts, :role_name, :string, :null => true
  end
end
