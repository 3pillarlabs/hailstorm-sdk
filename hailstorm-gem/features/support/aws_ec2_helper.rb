# frozen_string_literal: true

# Methods for AWS EC2 resource usage
module AwsEc2Helper

  # @param [String] region
  # @return [Aws::EC2::Client]
  def ec2_client(region:)
    Aws::EC2::Client.new(
      region: region,
      credentials: Aws::Credentials.new(*aws_keys)
    )
  end

  # @param [String] region
  # @return [Aws::EC2::Resource]
  def ec2_resource(region:)
    Aws::EC2::Resource.new(client: ec2_client(region: region))
  end

  def terminate_agents(region, *load_agents)
    ec2 = ec2_resource(region: region)
    load_agents.each do |agent|
      ec2_instance = ec2.instances(instance_ids: [agent.identifier]).first
      ec2_instance&.terminate
    end
  end

  # @param [String] region
  # @param [String] key_name
  # @return [Aws::EC2::KeyPair]
  def create_key_pair(region:, key_name:)
    ec2 = ec2_resource(region: region)
    key_pair = ec2.key_pairs(filters: [{ name: 'key-name', values: [key_name] }]).to_a.first
    return key_pair if key_pair

    ec2.create_key_pair(key_name: key_name)
  end

  # @param [String] region
  # @param [Aws::EC2::Resource] ec2
  # @return [Aws::EC2::Image, nil]
  def find_most_recent_amazon_ami(region:, ec2: nil)
    ec2 ||= ec2_resource(region: region)
    params = {
      owners: ['amazon'],
      filters: [
        { name: 'is-public', values: [true.to_s] },
        { name: 'architecture', values: ['x86_64'] },
        { name: 'image-type', values: ['machine'] },
        { name: 'root-device-type', values: ['ebs'] }
      ]
    }

    most_recent_image = proc do |a, b|
      t1 = Time.parse(a.creation_date)
      t2 = Time.parse(b.creation_date)
      t2 <=> t1
    end

    collection = ec2.images(params)
                    .select { |image| image.name =~ /amzn2-ami-hvm-2\.0/ }
                    .sort { |a, b| most_recent_image.call(a, b) }

    collection.first
  end

  # @param [Hash] params
  # @param [String (frozen)] instance_type
  # @param [Integer] count
  # @return [Enumerable<Aws::EC2::Instance>]
  def create_instances(params: {},
                       instance_type: 't3a.nano',
                       count: 1)

    ec2 = ec2_resource(region: params[:region])
    collection = ec2.create_instances(
      image_id: params[:image_id],
      subnet_id: params[:subnet_id],
      key_name: params[:key_name],
      security_group_ids: [params[:security_group_id]],
      instance_type: instance_type,
      min_count: count,
      max_count: count
    )

    %i[instance_running instance_status_ok system_status_ok].each do |waiter_name|
      ec2.client.wait_until(waiter_name, instance_ids: collection.map(&:id))
    end

    collection
  end

  # @param [String] region
  # @param [String] key_pair_id
  # @return [Boolean]
  def key_pair_exists?(region:, key_pair_id:)
    ec2 = ec2_resource(region: region)
    ec2.key_pairs(key_pair_ids: [key_pair_id]).to_a.empty? == false
  end

  # AWS EC2 instances tagged with provided tags.
  # Provided tags can be namespaced with Hash values as a Hash.
  # @param [String] region
  # @param [Hash] tags
  # @return Enumerable<Aws::EC2::Instance>
  def tagged_ec2_instances(region:, tags:)
    ec2 = ec2_resource(region: region)
    ec2.instances(filters: to_tag_filters(tags).push({ name: 'instance-state-name', values: ['running'] })).to_a
  end

  # @param [String] region
  # @param [Hash] tags
  # @return Enumerable<Aws::EC2::KeyPairInfo>
  def tagged_key_pairs(region:, tags:)
    ec2 = ec2_resource(region: region)
    ec2.key_pairs(filters: to_tag_filters(tags)).to_a
  end

  # @param [String] region
  # @param [Hash] tags
  # @return Enumerable<Aws::EC2::Image>
  def tagged_images(region:, tags:)
    ec2 = ec2_resource(region: region)
    ec2.images(filters: to_tag_filters(tags).push({ name: 'state', values: ['available'] })).to_a
  end

  # @param [String] region
  # @param [String] image_name
  # @return [Enumerable<Aws::EC2::Image>]
  def search_owned_images(region:, image_name:)
    ec2 = ec2_resource(region: region)
    ec2.images(owners: ['self'], filters: [{ name: 'name', values: [image_name] }]).to_a
  end
end
