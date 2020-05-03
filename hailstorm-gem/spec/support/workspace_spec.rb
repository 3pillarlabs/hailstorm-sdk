require 'spec_helper'

require 'hailstorm/support/workspace'

describe Hailstorm::Support::Workspace do

  context '#make_app_layout' do
    it 'should create the directory layout' do
      rel_paths = []
      FileUtils.stub!(:mkdir_p) { |path| rel_paths << path }
      Hailstorm::Support::Workspace.any_instance.stub(:create_file_layout)
      workspace = Hailstorm::Support::Workspace.new('workspace_spec')
      layout = {
          jmeter: {
              a: nil,
              b: {
                  c: nil,
                  d: { e: nil }
              }
          }
      }.deep_stringify_keys
      workspace.make_app_layout(layout)
      expect(rel_paths).to include(workspace.app_path)
      expect(rel_paths).to include("#{workspace.app_path}/a")
      expect(rel_paths).to include("#{workspace.app_path}/b")
      expect(rel_paths).to include("#{workspace.app_path}/b/c")
      expect(rel_paths).to include("#{workspace.app_path}/b/d")
      expect(rel_paths).to include("#{workspace.app_path}/b/d/e")
    end
  end

  context '#open_app_file' do
    it 'should yield a file object' do
      Hailstorm::Support::Workspace.any_instance.stub(:create_file_layout)
      workspace = Hailstorm::Support::Workspace.new('workspace_spec')
      File.stub!(:join).and_return(File.expand_path('../../../features/data/hailstorm-site-basic.jmx', __FILE__))
      file_objects = []
      workspace.open_app_file('any') { |io| file_objects << io }
      expect(file_objects).to_not be_empty
    end
  end

  context '#app_entries' do
    it 'should return list of full paths to artifacts in app directory' do
      workspace = Hailstorm::Support::Workspace.new('workspace_spec')
      expect(workspace.app_entries).to be_empty
    end
  end

  context '#remove_workspace' do
    it 'should delete the project workspace directory' do
      workspace = Hailstorm::Support::Workspace.new('workspace_spec')
      workspace.create_file_layout
      expect(File.exist?(workspace.workspace_path)).to be_true
      workspace.remove_workspace
      expect(File.exist?(workspace.workspace_path)).to be_false
    end
  end
end
