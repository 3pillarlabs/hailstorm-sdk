class AmazonCloud < Cluster

  AMAZON_CLUSTER_REGIONS = [
      { 'us-east-1' =>  'US East (Virginia)' },
      { 'us-west-1' =>  'US West (N. California)' },
      { 'us-west-2' =>  'US West (Oregon)' },
      { 'eu-west-1' =>   'Europe West (Ireland)' },
      { 'eu-central-1' =>   'Europe Central (Frankfurt)' },
      { 'ap-northeast-1' => 'Asia Pacific (Tokyo)' },
      { 'ap-southeast-1' =>  'Asia Pacific (Singapore)' },
      { 'sa-east-1' =>  'South America (Sao Paulo)' },
      { 'ap-southeast-2' =>  'Asia Pacific (Sydney)' }
  ]

  AMAZON_INSTANCE_TYPES = %w(m3.medium m3.large c3.2xlarge c3.4xlarge)

  validates :access_key, :secret_key, :region, :instance_type, presence: true
  validates_presence_of :max_threads_per_agent, unless: ->(r) { r.known_instance_type? }
  validates_numericality_of :max_threads_per_agent, unless: ->(r) { r.max_threads_per_agent.nil? }

  @@regions = nil
  def self.regions
    @@regions ||= AMAZON_CLUSTER_REGIONS.reduce([]) { |s, e| s << OpenStruct.new(id: e.keys.first, name: e.values.first) }.freeze
  end

  @@instance_types = nil
  def self.instance_types
    @@instance_types ||= AMAZON_INSTANCE_TYPES.reduce([]) { |s, e| s << OpenStruct.new(id: e, name: e) }.freeze
  end

  def initialize(*args)
    super
    self.region = 'us-east-1' if self.region.nil?
    self.instance_type = 'm3.medium' if self.instance_type.nil?
    self.max_threads_per_agent = AmazonCloud.max_threads_per_agent_matrix[self.instance_type] if self.max_threads_per_agent.nil?
  end

  @@max_threads_per_agent_matrix = nil
  def self.max_threads_per_agent_matrix
    @@max_threads_per_agent_matrix ||= {
        'm3.medium' => 50,
        'm3.large' => 200,
        'c3.2xlarge' => 800,
        'c3.4xlarge' => 1000
    }.freeze
  end

  def region_title
    AMAZON_CLUSTER_REGIONS.find { |e| e.keys.first == self.region}.values.first
  end

  def known_instance_type?
    AMAZON_INSTANCE_TYPES.include? self.instance_type
  end

end