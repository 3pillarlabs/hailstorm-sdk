class Cluster < ActiveRecord::Base
  belongs_to :project

  validates :name, presence: true
  has_attached_file :ssh_identity,
                    :path => Rails.configuration.uploads_path+"/ssh_identity_Files/:project_id/:basename.:extension",
                    :url => "/ssh_identity_Files/:project_id/:basename.:extension"
  validates_attachment_file_name :ssh_identity, :matches => [/pem\Z/]
  validate :check_form_for_spoofed_and_mandatory_data

  AMAZON_CLUSTER_REGIONS = {"us-east-1"=>"us-east-1","us-west-1"=>"us-west-1","us-west-2"=>"us-west-2","eu-west-1"=>"eu-west-1","ap-northeast-1"=>"ap-northeast-1","ap-southeast-1"=>"ap-southeast-1","sa-east-1"=>"sa-east-1"}
  AMAZON_INSTANCE_TYPES = {"m1.small"=>"m1.small","m1.large"=>"m1.large","m1.xlarge"=>"m1.xlarge","c1.xlarge"=>"c1.xlarge"}

  after_create :check_project_clusters

  def check_form_for_spoofed_and_mandatory_data
    if name.present? and !(name == "amazon_cloud" or name == "data_center")
      errors.add(:name, "can't change cluster name")
    elsif name == "amazon_cloud"

      if !access_key.present?
        errors.add(:access_key, " can't be blank")
      end

      if !secret_key.present?
        errors.add(:secret_key, " can't be blank")
      end

      if !region.present?
        errors.add(:region, " can't be blank")
      end

      if !instance_type.present?
        errors.add(:instance_type, " can't be blank")
      end

      if !AMAZON_CLUSTER_REGIONS.has_value?(region)
        errors.add(:region, "must be from the list")
      end

      if !AMAZON_INSTANCE_TYPES.has_value?(instance_type)
        errors.add(:instance_type, "must be from the list")
      end
    elsif name == "data_center"
      if !user_name.present?
        errors.add(:user_name, " can't be blank")
      end

      if !machines.present? or machines == "[]"
        errors.add(:machines, " can't be blank")
      end
    end

  end

  def self.pagination(current_page, items_per_page)
    self.paginate(page: current_page, per_page: items_per_page).order("updated_at DESC")
  end

  def getClustersOfType(type, project_id)
    clusters = Cluster.where(:project_id=>project_id, :name => type)
    return clusters
  end

  def check_project_clusters
    project.transition_state if project.clusters.count==1
  end

end
