class AddTypeToClusters < ActiveRecord::Migration
  def change
    add_column :clusters, :type, :string
  end
end
