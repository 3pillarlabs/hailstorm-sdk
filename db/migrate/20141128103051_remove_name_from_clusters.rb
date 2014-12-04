class RemoveNameFromClusters < ActiveRecord::Migration
  def change
    remove_column :clusters, :name, :string
  end
end
