class ChangeColoumnNameOfTypeInTargetHosts < ActiveRecord::Migration
  def change
    rename_column :target_hosts, :type, :target_host_type
  end
end
