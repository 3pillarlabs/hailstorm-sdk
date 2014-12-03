class RemoveExecutablePidFormTargetHosts < ActiveRecord::Migration
  def change
    remove_column :target_hosts, :executable_pid
  end
end
