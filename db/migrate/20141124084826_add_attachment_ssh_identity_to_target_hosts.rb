class AddAttachmentSshIdentityToTargetHosts < ActiveRecord::Migration
  def self.up
    change_table :target_hosts do |t|
      t.attachment :ssh_identity
    end
  end

  def self.down
    remove_attachment :target_hosts, :ssh_identity
  end
end
