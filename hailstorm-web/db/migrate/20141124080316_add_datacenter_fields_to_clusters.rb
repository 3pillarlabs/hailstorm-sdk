class AddDatacenterFieldsToClusters < ActiveRecord::Migration
  def change
    add_column :clusters, :user_name, :string
    add_column :clusters, :machines, :text
  end
end
