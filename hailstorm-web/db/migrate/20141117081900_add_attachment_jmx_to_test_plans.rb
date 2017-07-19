class AddAttachmentJmxToTestPlans < ActiveRecord::Migration
  def self.up
    change_table :test_plans do |t|
      t.attachment :jmx
    end
  end

  def self.down
    remove_attachment :test_plans, :jmx
  end
end
