# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

# Helper for EC2 prices
module AwsEc2PricingHelper

  A1_INSTANCE_TYPE = /^a1\./.freeze

  # @param [String] region
  # @param [Time] timestamp
  # @return [String] JSON array [hash] hash.keys = %w[instanceType hourlyCostByInstance]
  def fetch_ec2_prices(region:, timestamp:)
    json_data = fetch_price_data(region, timestamp)
    selected_item_attrs = json_data['prices'].select(&method(:select_item?)).map(&method(:projection))
    JSON.dump(selected_item_attrs)
  end

  private

  def projection(item)
    item_attrs = item['attributes']
    {
      hourlyCostByInstance: item['price']['USD'].to_f,
      clockSpeed: item_attrs['aws:ec2:clockSpeed'],
      dedicatedEbsThroughput: item_attrs['aws:ec2:dedicatedEbsThroughput'],
      instanceType: item_attrs['aws:ec2:instanceType'],
      memory: item_attrs['aws:ec2:memory'],
      networkPerformance: item_attrs['aws:ec2:networkPerformance'],
      normalizationSizeFactor: item_attrs['aws:ec2:normalizationSizeFactor'],
      vcpu: item_attrs['aws:ec2:vcpu'],
      id: item['id']
    }
  end

  # @param [Hash] item item.keys = %w[id unit price attributes]
  def select_item?(item)
    item['attributes']['aws:ec2:instanceFamily'] == 'General purpose' &&
      item['unit'] == 'Hrs' &&
      item['attributes']['aws:ec2:instanceType'] !~ A1_INSTANCE_TYPE
  end

  def fetch_price_data(region, timestamp)
    uri_query = "timestamp=#{timestamp.to_i * 1000}"
    uri = URI("https://a0.p.awsstatic.com/pricing/1.0/ec2/region/#{region}/ondemand/linux/index.json?#{uri_query}")
    response = Net::HTTP.get_response(uri)
    raise(Net::HTTPError.new("Failed to fetch #{uri}", response)) unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
