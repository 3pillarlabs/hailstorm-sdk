class AddAttachmentSshIdentityToClusters < ActiveRecord::Migration
  def self.up
    change_table :clusters do |t|
      t.attachment :ssh_identity
    end
  end

  def self.down
    remove_attachment :clusters, :ssh_identity
  end
end
