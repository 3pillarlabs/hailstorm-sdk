class AddDefaultValueToTargetHostsUsername < ActiveRecord::Migration
  def change
    change_column :target_hosts,:user_name,:string,:default=> "ubuntu"
  end
end
