# Internet Gateway Client adapter
class Hailstorm::Support::AwsAdapter::InternetGatewayClient < Hailstorm::Support::AwsAdapter::AbstractClient
  include Hailstorm::Behavior::AwsAdaptable::InternetGatewayClient

  def attach(igw_id:, vpc_id:)
    ec2.attach_internet_gateway(internet_gateway_id: igw_id, vpc_id: vpc_id)
  end

  def create
    resp = ec2.create_internet_gateway
    resp.internet_gateway.internet_gateway_id
  end
end
