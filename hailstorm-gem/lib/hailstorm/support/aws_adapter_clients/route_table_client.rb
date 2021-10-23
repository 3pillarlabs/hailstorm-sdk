# frozen_string_literal: true

# Route table (within a VPC) adapter
class Hailstorm::Support::AwsAdapter::RouteTableClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::RouteTableClient

  def associate_with_subnet(route_table_id:, subnet_id:)
    resp = ec2.associate_route_table(route_table_id: route_table_id, subnet_id: subnet_id)
    resp.association_id
  end

  def create(vpc_id:)
    resp = ec2.create_route_table(created_tag_specifications('route-table', vpc_id: vpc_id))
    resp.route_table.route_table_id
  end

  def create_route(route_table_id:, cidr:, internet_gateway_id:)
    ec2.create_route(destination_cidr_block: cidr,
                     gateway_id: internet_gateway_id,
                     route_table_id: route_table_id)
  end

  def main_route_table(vpc_id:)
    params = { filters: [to_vpc_filter(vpc_id)] }
    rtb = describe_route_tables(params).find do |route_table|
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

  def route_tables(vpc_id:, filters: [])
    params = { filters: [to_vpc_filter(vpc_id)] }
    add_filters_to_params(filters, params)
    describe_route_tables(params).map do |route_table|
      Hailstorm::Behavior::AwsAdaptable::RouteTable.new(id: route_table.route_table_id,
                                                        main: route_table.associations.any?(&:main))
    end
  end

  def delete(route_table_id:)
    ec2.delete_route_table(route_table_id: route_table_id)
  end

  private

  def to_vpc_filter(vpc_id)
    { name: 'vpc-id', values: [vpc_id] }
  end

  # @param [Hash] params
  # @return [Array<Aws::EC2::Types::RouteTable>]
  def describe_route_tables(params)
    ec2.describe_route_tables(params).route_tables
  end
end
