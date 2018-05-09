require 'hailstorm/controller'
require 'hailstorm/behavior/loggable'
require 'hailstorm/model/project'

# Base controller
# @author Sayantam Dey
module Hailstorm::Controller::Application

  include Hailstorm::Behavior::Loggable

  attr_reader :middleware

  # Create a new CLI instance
  # @param [Hailstorm::Middleware::Application] middleware instance
  def initialize(middleware)
    @middleware = middleware
  end

  def current_project
    @current_project ||= Hailstorm::Model::Project.where(project_code: Hailstorm.app_name).first_or_create!
  end
end
