class TargetHost < ActiveRecord::Base

  SSH_IDENTITY_BASE_DIR = 'target_hosts_ssh_identity_Files'

  belongs_to :project

  validates :executable_path, :user_name, :sampling_interval, presence: true
  validates_presence_of :role_name, :host_name, :message => 'Configuration must have at least 1 role and 1 host'
  has_attached_file :ssh_identity,
                    :path => "#{Rails.configuration.uploads_path}/#{SSH_IDENTITY_BASE_DIR}/:project_id/:basename.:extension",
                    :url => "/#{SSH_IDENTITY_BASE_DIR}/:project_id/:basename.:extension"
  validates_attachment_file_name :ssh_identity, :matches => [/pem\Z/]
  validates_presence_of :ssh_identity

  def initialize(*args)
    super
    self.executable_path = '/usr/local/bin/nmon' if self.executable_path.nil?
  end


  # Converts target hosts in project to a data structure suitable for integration via hailstorm-redis
  #   {
  #       monitor_type: nmon,
  #       groups: [
  #         {
  #           role_name: 'Database',
  #           hosts: [
  #             {
  #               host_name: 'www.example.com',
  #               executable_path: '/usr/local/bin/nmon'
  #               ...
  #             },
  #             {...}
  #           ]
  #         },
  #         {...}
  #       ]
  #   }
  # @param [Project] project
  # @return [String]
  def self.as_json(project)
    {
        monitor_type: :nmon,
        groups: project.target_hosts.reduce([]) do
          # @type groups [Array]
          # @type target_host [TargetHost]
        |groups, target_host|
          group = groups.find { |g| g[:role_name] == target_host.role_name }
          if group.nil?
            group = {
                role_name: target_host.role_name,
                hosts: []
            }
            groups.push(group)
          end
          group[:hosts].push({
                                 host_name: target_host.host_name,
                                 executable_path: target_host.executable_path,
                                 user_name: target_host.user_name,
                                 sampling_interval: target_host.sampling_interval,
                                 ssh_identity: target_host.ssh_identity_file_name
                             })
          groups
        end
    }
  end
end
