class TestPlan < ActiveRecord::Base

  belongs_to :project

  has_attached_file :jmx,
                    :path => "#{Rails.configuration.uploads_path}/Jmx_Files/:project_id/:basename.:extension"

  do_not_validate_attachment_file_type  :jmx
  validates :jmx_file_name, :uniqueness => {:scope => :project_id, :message => " has already been taken for this project." }
  validates :jmx_file_name, :presence => { :message => " is empty, please upload a valid JMX file" }

  attr_accessor :property_name, :property_value

  after_create :transition_project

  def getProjectTestPlans(projectId)
    TestPlan.where(:project_id => projectId)
  end

  def self.pagination(current_page, items_per_page)
    self.paginate(page: current_page, per_page: items_per_page).order("updated_at DESC")
  end

  def transition_project
    self.project.test_plan_upload! # trigger event
    unless self.project.clusters.empty?
      self.project.config_completed!
    end
  end

  # @return [Boolean] true if the file_name ends in .jmx
  def test_plan?
    /\.jmx$/.match(self.jmx_file_name)
  end

  # @return [String] contents of the text file
  def content
    File.read(self.jmx.path)
  end

end
