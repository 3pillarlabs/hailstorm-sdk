require 'active_support/all'

# Defines the namespace.
# @author Sayantam Dey
module Hailstorm

  PROJECT_WORKSPACE_KEY = :project_workspace_key

  # Reference to FileStore implementation
  # @return [Hailstorm::Behavior::FileStore]
  mattr_accessor :fs

  # Workspace reference for workspace actions
  # @return [Hailstorm::Support::Workspace]
  def self.workspace(project_code)
    current_thread = Thread.current
    unless current_thread.thread_variable?(PROJECT_WORKSPACE_KEY)
      current_thread.thread_variable_set(PROJECT_WORKSPACE_KEY, {})
    end

    # @type [Hash] project_workspace
    project_workspace = current_thread.thread_variable_get(PROJECT_WORKSPACE_KEY)
    unless project_workspace.key?(project_code)
      require 'hailstorm/support/workspace'
      project_workspace[project_code] = Hailstorm::Support::Workspace.new(project_code)
      current_thread.thread_variable_set(PROJECT_WORKSPACE_KEY, project_workspace)
    end

    project_workspace[project_code]
  end

  # @return [String] path to templates directory
  def self.gem_templates_path
    File.expand_path('../../templates', __FILE__)
  end

  # @return [Symbol] current environment, default :development
  def self.env
    (ENV['HAILSTORM_ENV'] || :development).to_sym
  end

  # Directory name for application specific (JMeter) artifacts
  def self.app_dir
    'jmeter'
  end

  def self.log_dir
    'log'
  end
end
