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

  AMAZON_CLUSTER_REGIONS = {"us-east-1"=>"us-east-1","us-west-1"=>"us-west-1","us-west-2"=>"us-west-2","eu-west-1"=>"eu-west-1","ap-northeast-1"=>"ap-northeast-1","ap-southeast-1"=>"ap-southeast-1","sa-east-1"=>"sa-east-1"}
  AMAZON_INSTANCE_TYPES = {"m1.small"=>"m1.small","m1.large"=>"m1.large","m1.xlarge"=>"m1.xlarge","c1.xlarge"=>"c1.xlarge"}

  after_create :transition_project

  def self.pagination(current_page, items_per_page)
    self.paginate(page: current_page, per_page: items_per_page).order("updated_at DESC")
  end

  def transition_project
    self.project.cluster_configuration! # trigger state event
    unless self.project.test_plans.empty?
      self.project.config_completed!
    end
  end

end
