class CreateClusters < ActiveRecord::Migration
  def change
    create_table :clusters do |t|
      t.references :project, index: true, :null => false
      t.string :name, :null => false, :default=> "amazon_cloud"
      t.string :access_key, :null => false
      t.string :secret_key, :null => false
      t.string :ssh_identity, :null => true
      t.string :region, :null => false
      t.string :instance_type, :null => false

      t.timestamps
    end
  end
end
