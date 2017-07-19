class Cluster < ActiveRecord::Base
  belongs_to :project
  scope :data_centers, -> { where(type: 'DataCenter') }
  scope :amazon_clouds, -> { where(type: 'AmazonCloud') }

  def self.types
    %w(DataCenter AmazonCloud)
  end

  has_attached_file :ssh_identity,
                    :path => Rails.configuration.uploads_path+"/ssh_identity_Files/:project_id/:basename.:extension",
                    :url => "/ssh_identity_Files/:project_id/:basename.:extension"
  validates_attachment_file_name :ssh_identity, :matches => [/pem\Z/]

  after_create :transition_project

  include Deletable

  def self.pagination(current_page, items_per_page)
    self.paginate(page: current_page, per_page: items_per_page).order("updated_at DESC")
  end

  def transition_project
    self.project.cluster_configuration! if self.project.may_cluster_configuration? # trigger state event
    unless self.project.test_plans.empty?
      self.project.config_completed! if self.project.may_config_completed?
    end
  end

end
