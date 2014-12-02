class TargetHost < ActiveRecord::Base
  belongs_to :project

  validates :executable_path, :user_name, :sampling_interval, presence: true
  has_attached_file :ssh_identity,
                    :path => Rails.configuration.uploads_path+"/target_hosts_ssh_identity_Files/:project_id/:basename.:extension",
                    :url => "/target_hosts_ssh_identity_Files/:project_id/:basename.:extension"
  validates_attachment_file_name :ssh_identity, :matches => [/pem\Z/]
  #validates :ssh_identity_file_name, :presence => { :message => " is empty, please upload a valid SSH file" }

end
