class DataCenter < Cluster
  validates :user_name, :machines, :title, presence: true
end