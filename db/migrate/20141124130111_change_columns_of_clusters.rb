class ChangeColumnsOfClusters < ActiveRecord::Migration
  def change
    change_table :clusters do |t|
      t.change :access_key, :string, :null => true
      t.change :secret_key, :string, :null => true
      t.change :region, :string, :null => true
      t.change :instance_type, :string, :null => true
    end
  end
end
