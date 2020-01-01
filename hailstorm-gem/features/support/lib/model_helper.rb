# Model Helper
module ModelHelper

  def find_project(project_code)
    Hailstorm::Model::Project.where(project_code: project_code).first_or_create!
  end
end
