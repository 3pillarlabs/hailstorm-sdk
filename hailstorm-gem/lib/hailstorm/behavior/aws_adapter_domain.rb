# frozen_string_literal: true

require 'hailstorm/behavior'

# Types for AWS Adapter
module Hailstorm::Behavior::AwsAdapterDomain

  # Snapshot (id|snapshot_id: String, status: Symbol)
  Snapshot = Struct.new(:snapshot_id, :state, keyword_init: true) do
    def id
      snapshot_id
    end

    def status
      state.to_sym
    end

    def completed?
      status == :completed
    end
  end

  # KeyPairInfo (key_fingerprint: String, key_name: String, key_pair_id: String)
  KeyPairInfo = Struct.new(:key_fingerprint, :key_name, :key_pair_id, keyword_init: true)

  # KeyPair has information at the time of creation.
  # KeyPair (key_fingerprint: String, key_name: String, key_pair_id: String, key_material|private_key: String)
  KeyPair = Struct.new(:key_fingerprint, :key_name, :key_pair_id, :key_material, keyword_init: true) do
    def private_key
      key_material
    end
  end

  # InstanceState(name: String, code: Fixnum)
  InstanceState = Struct.new(:code, :name, keyword_init: true)

  # Instance(id|instance_id: String, state: InstanceState, public_ip_address: String, private_ip_address: String)
  Instance = Struct.new(:instance_id, :state, :public_ip_address, :private_ip_address, keyword_init: true) do
    def status
      state.name.to_sym
    end

    def id
      instance_id
    end

    %w[pending running shutting-down terminated stopping stopped].each do |state_name|
      define_method("#{state_name.tr('-', '_')}?") { state_name.to_sym == status }
    end
  end

  # SecurityGroup(group_name: String, id|group_id: String, vpc_id: String?)
  SecurityGroup = Struct.new(:group_name, :group_id, :vpc_id, keyword_init: true) do
    def id
      group_id
    end
  end

  # InstanceStateChange(id|instance_id: String, status: Symbol,
  #                     current_state: InstanceState, previous_state: InstanceState)
  #   InstanceStateChange#status #=> current_state.name
  InstanceStateChange = Struct.new(:instance_id, :current_state, :previous_state, keyword_init: true) do
    def id
      instance_id
    end

    def status
      current_state.name.tr('-', '_').to_sym
    end
  end

  # StateReason (code: String, message: String)
  StateReason = Struct.new(:code, :message, keyword_init: true)

  # VPC (id|vpc_id: String, state: String, status: Symbol)
  Vpc = Struct.new(:vpc_id, :state, keyword_init: true) do
    def id
      vpc_id
    end

    def status
      state.to_sym
    end

    def available?
      status == :available
    end
  end

  # Ami(id|image_id|ami_id: String, state: Symbol, name: String, state_reason: StateReason, snapshot_id: String)
  class Ami

    attr_reader :image_id, :name, :state, :state_reason, :snapshot_id

    # @param [String] image_id
    # @param [String] state
    # @param [String] name
    # @param [StateReason] state_reason
    # @param [String] snapshot_id
    def initialize(image_id: nil, state: nil, name: nil, state_reason: nil, snapshot_id: nil)
      @image_id = image_id
      @state = state ? state.to_sym : nil
      @name = name
      @snapshot_id = snapshot_id
    end

    def id
      image_id
    end

    def ami_id
      image_id
    end

    def available?
      state == :available
    end
  end

  # Route(state: String)
  class Route

    attr_reader :state

    # @param [String] state
    def initialize(state: nil)
      @state = state ? state.to_sym : nil
    end

    def active?
      state == :active
    end
  end

  # RouteTable(id: String, main: Boolean)
  RouteTable = Struct.new(:id, :main, keyword_init: true)

  # InternetGateway(id: String)
  InternetGateway = Struct.new(:id, keyword_init: true)

  CLIENT_KEYS = %i[ec2_client key_pair_client security_group_client instance_client ami_client
                   subnet_client vpc_client internet_gateway_client route_table_client].freeze

  ClientFactory = Struct.new(*CLIENT_KEYS, keyword_init: true)
end
