class DataCenter < Cluster
  validates :user_name, :machines, presence: true
end