class AddMaxThreadsToClusters < ActiveRecord::Migration
  def change
    add_column :clusters, :max_threads_per_agent, :integer
  end
end
