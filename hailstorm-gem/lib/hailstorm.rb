require 'active_support/all'

# Defines the namespace.
# @author Sayantam Dey
module Hailstorm

  # Reference to FileStore implementation
  # @return [Hailstorm::Behavior::FileStore]
  mattr_accessor :fs

  # Workspace reference for workspace actions
  # @return [Hailstorm::Support::Workspace]
  def self.workspace(project_code)
    require 'hailstorm/support/workspace'
    Hailstorm::Support::Workspace.new(project_code)
  end

  # @return [String] path to templates directory
  def self.gem_templates_path
    File.expand_path('../../templates', __FILE__)
  end
end
