# frozen_string_literal: true

include ModelHelper

Given(/^(?:Hailstorm is initialized with a project|the) ['"]([^'"]+)['"](?:| project(?:| is active))$/) do |project_code|
  require 'hailstorm/model/project'
  @project = find_project(project_code)
  require 'hailstorm/support/configuration'
  @hailstorm_config = Hailstorm::Support::Configuration.new
end
