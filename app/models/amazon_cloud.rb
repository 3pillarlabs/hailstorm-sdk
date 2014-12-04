class AmazonCloud < Cluster
  validates :access_key, :secret_key, :region, :instance_type, presence: true
end