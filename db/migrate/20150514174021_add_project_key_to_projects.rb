class AddProjectKeyToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :project_key, :string
  end
end
