# frozen_string_literal: true

# Client adapter for EC2 methods invoked
class Hailstorm::Support::AwsAdapter::Ec2Client < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::Ec2Client

  def first_available_zone
    zone = ec2.describe_availability_zones
              .availability_zones
              .find { |z| z.state.to_sym == :available }

    zone ? zone.zone_name : nil
  end

  def find_vpc(subnet_id:)
    resp = ec2.describe_subnets(subnet_ids: [subnet_id])
    return nil if resp.subnets.empty?

    resp.subnets[0].vpc_id
  end

  def find_self_owned_snapshots
    resp = ec2.describe_snapshots(owner_ids: ['self'])
    resp.snapshots.lazy.map do |snapshot|
      Hailstorm::Behavior::AwsAdaptable::Snapshot.new(snapshot_id: snapshot.snapshot_id, state: snapshot.state)
    end
  end

  def delete_snapshot(snapshot_id:)
    ec2.delete_snapshot(snapshot_id: snapshot_id)
  end
end
