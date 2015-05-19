class AddStateReasonToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :state_reason, :string
  end
end
