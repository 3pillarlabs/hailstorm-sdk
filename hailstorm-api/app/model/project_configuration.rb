require 'active_record/base'
require 'hailstorm/model/project'

# Hailstorm configuration persistence model
class ProjectConfiguration < ActiveRecord::Base

  belongs_to :project, class_name: Hailstorm::Model::Project.name
end
