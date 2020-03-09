require 'spec_helper'
require 'helpers/aws_ec2_pricing_helper'

describe AwsEc2PricingHelper do
  include AwsEc2PricingHelper

  context '#fetch_ec2_prices' do
    it 'should fetch and parse EC2 general purpose instance types' do
      response = mock(Net::HTTPResponse)
      response.stub!(:is_a?).and_return(true)
      response.stub!(:body).and_return(File.read(File.join(File.expand_path('../../resources', __FILE__), 'ec2-us-east-1-prices.json')))
      Net::HTTP.stub!(:get_response).and_return(response)

      raw_data = fetch_ec2_prices(region: 'us-east-1', timestamp: Time.now)
      json_data = JSON.parse(raw_data)
      expect(json_data.size).to be > 0
      expect(json_data[0].keys).to include('hourlyCostByInstance')
      expect(json_data[0].keys).to include('instanceType')
      expect(json_data.select(&:nil?)).to be_empty
    end
  end
end
