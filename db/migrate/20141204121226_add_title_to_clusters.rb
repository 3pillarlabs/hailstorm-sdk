class AddTitleToClusters < ActiveRecord::Migration
  def change
    add_column :clusters, :title, :string
  end
end
