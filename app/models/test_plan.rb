class TestPlan < ActiveRecord::Base
  belongs_to :project
  has_attached_file :jmx,
                    :path => ":rails_root/public/Jmx_Files/:project_id/:basename.:extension",
                    :url => "/Jmx_Files/:project_id/:basename.:extension"
  validates_attachment_file_name :jmx, :matches => [/jmx\Z/]
  validates :jmx_file_name, :uniqueness => {:scope => :project_id, :message => " has already been taken for this project." }
  validates :jmx_file_name, :presence => { :message => " is empty, please upload a valid JMX file" }
  attr_accessor :property_name, :property_value

  def getProjectTestPlans(projectId)
    test_plans = TestPlan.joins(:project).where(:project_id => projectId)
    # test_plans = TestPlan.joins('RIGHT OUTER JOIN projects ON test_plans.project_id = projects.id').where('projects.id' => projectId).select("projects.title, test_plans.*")
    return test_plans
  end

  def self.pagination(current_page, items_per_page)
    self.paginate(page: current_page, per_page: items_per_page).order("updated_at DESC")
  end

  def getTestPlanProperties(testPlanId)
    testPlanPropertiesJSON = []
    testPlanProperties = TestPlan.where(id: testPlanId).select("properties").take
    if(!testPlanProperties.properties.nil?)
      testPlanPropertiesJSON = JSON.parse(testPlanProperties.properties)
    end
    return testPlanPropertiesJSON
  end

end
