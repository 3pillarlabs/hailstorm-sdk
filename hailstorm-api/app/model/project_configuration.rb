require 'active_record/base'
require 'hailstorm/model/project'

class ProjectConfiguration < ActiveRecord::Base

  belongs_to :project, class_name: Hailstorm::Model::Project
end
