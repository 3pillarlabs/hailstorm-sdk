class RemoveSshIdentityColoumnFromCluster < ActiveRecord::Migration
  def change
    remove_column :clusters,:ssh_identity
  end
end
