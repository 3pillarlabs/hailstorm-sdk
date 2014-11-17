class CreateTestPlans < ActiveRecord::Migration
  def change
    create_table :test_plans do |t|
      t.integer :project_id
      t.boolean :status , :default=> -1, :null => false
      t.string :default

      t.timestamps
    end
  end
end
