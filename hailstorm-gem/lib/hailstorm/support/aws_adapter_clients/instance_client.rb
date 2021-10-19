# frozen_string_literal: true

# EC2 Instance adapter
class Hailstorm::Support::AwsAdapter::InstanceClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::InstanceClient

  def find(instance_id:, max_find_tries: 3, wait_seconds: 20)
    num_tries = 0
    resp = nil
    begin
      resp = ec2.describe_instances(instance_ids: [instance_id])
    rescue Aws::EC2::Errors::ServiceError
      raise if num_tries >= max_find_tries

      num_tries += 1
      sleep(wait_seconds)
      retry
    end

    return if resp.reservations.blank? || resp.reservations[0].instances.blank?

    decorate(instance: resp.reservations[0].instances[0])
  end

  def decorate(instance:)
    Hailstorm::Behavior::AwsAdaptable::Instance.new(
      instance_id: instance.instance_id,
      state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(
        name: instance.state.name,
        code: instance.state.code
      ),
      public_ip_address: instance.public_ip_address,
      private_ip_address: instance.private_ip_address
    )
  end
  private :decorate

  def running?(instance_id:)
    instance = find(instance_id: instance_id)
    instance ? instance.running? : false
  end

  def start(instance_id:)
    resp = ec2.start_instances(instance_ids: [instance_id])
    return if resp.starting_instances.empty?

    result = resp.starting_instances[0]
    to_transitional_attributes(result)
  end

  # @param [Aws::EC2::Types::InstanceStateChange] result
  # @return [Hailstorm::Behavior::AwsAdaptable::InstanceStateChange]
  def to_transitional_attributes(result)
    Hailstorm::Behavior::AwsAdaptable::InstanceStateChange.new(
      instance_id: result.instance_id,
      current_state: result.current_state,
      previous_state: result.previous_state
    )
  end
  private :to_transitional_attributes

  def stop(instance_id:)
    resp = ec2.stop_instances(instance_ids: [instance_id])
    return if resp.stopping_instances.empty?

    result = resp.stopping_instances[0]
    to_transitional_attributes(result)
  end

  def stopped?(instance_id:)
    instance = find(instance_id: instance_id)
    instance ? instance.stopped? : true
  end

  def terminate(instance_id:)
    resp = ec2.terminate_instances(instance_ids: [instance_id])
    return if resp.terminating_instances.empty?

    result = resp.terminating_instances[0]
    to_transitional_attributes(result)
  end

  def terminated?(instance_id:)
    instance = find(instance_id: instance_id)
    instance ? instance.terminated? : true
  end

  def create(instance_attrs, min_count: 1, max_count: 1)
    req_attrs = instance_attrs.except(:availability_zone)
    req_attrs[:min_count] = min_count
    req_attrs[:max_count] = max_count
    req_attrs[:placement] = instance_attrs.slice(:availability_zone) if instance_attrs.key?(:availability_zone)
    instance = ec2.run_instances(created_tag_specifications('instance', req_attrs)).instances[0]
    decorate(instance: instance)
  end

  def ready?(instance_id:)
    instance = find(instance_id: instance_id)
    return false unless instance

    instance.running? && systems_ok(instance)
  end

  def systems_ok(instance)
    reachability_pass = ->(f) { f.name == 'reachability' && f.status == 'passed' }
    resp = ec2.describe_instance_status(instance_ids: [instance.id])
    logger.debug { resp.to_h }
    resp.instance_statuses.reduce(true) do |state, e|
      system_unreachable = e.system_status.details.select { |f| reachability_pass.call(f) }.empty?
      instance_unreachable = e.instance_status.details.select { |f| reachability_pass.call(f) }.empty?
      state && !system_unreachable && !instance_unreachable
    end
  end
  private :systems_ok

  def list(instance_ids: nil)
    params = {}
    params[:instance_ids] = instance_ids unless instance_ids.nil?
    ec2.describe_instances(params).reservations.flat_map(&:instances).lazy.map do |instance|
      decorate(instance: instance)
    end
  end
end
