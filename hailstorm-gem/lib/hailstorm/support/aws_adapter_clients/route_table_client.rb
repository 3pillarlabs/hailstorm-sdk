# Route table (within a VPC) adapter
class Hailstorm::Support::AwsAdapter::RouteTableClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::RouteTableClient

  def associate_with_subnet(route_table_id:, subnet_id:)
    resp = ec2.associate_route_table(route_table_id: route_table_id, subnet_id: subnet_id)
    resp.association_id
  end

  def create(vpc_id:)
    resp = ec2.create_route_table(vpc_id: vpc_id)
    resp.route_table.route_table_id
  end

  def create_route(route_table_id:, cidr:, internet_gateway_id:)
    ec2.create_route(destination_cidr_block: cidr,
                     gateway_id: internet_gateway_id,
                     route_table_id: route_table_id)
  end

  def main_route_table(vpc_id:)
    resp = ec2.describe_route_tables(filters: [{ name: 'vpc-id', values: [vpc_id] }])
    rtb = resp.route_tables.find do |route_table|
      route_table.associations.any?(&:main)
    end

    rtb ? rtb.route_table_id : nil
  end

  def routes(route_table_id:)
    ec2.describe_route_tables(route_table_ids: [route_table_id])
       .route_tables
       .first
       .routes
       .map { |route| Hailstorm::Behavior::AwsAdaptable::Route.new(state: route.state) }
  end
end
