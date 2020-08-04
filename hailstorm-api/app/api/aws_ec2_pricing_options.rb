require 'sinatra'
require 'model/aws_ec2_price'
require 'helpers/aws_ec2_pricing_helper'
require 'hailstorm/model/helper/amazon_cloud_defaults'

include AwsEc2PricingHelper

AMAZON_CLOUD_DEFAULTS = Hailstorm::Model::Helper::AmazonCloudDefaults

get '/aws_ec2_pricing_options/:region_code' do |region_code|
  timestamp = Time.now
  region_price = AwsEc2Price.where(region: region_code).first
  if region_price.nil? || timestamp - region_price.next_update >= 0
    raw_prices_data = fetch_ec2_prices(region: region_code, timestamp: timestamp)
    if region_price.nil?
      AwsEc2Price.create!(region: region_code, raw_data: raw_prices_data, next_update: timestamp.next_quarter)
    else
      region_price.update_attributes!(raw_data: raw_prices_data, next_update: timestamp.next_quarter)
    end

  else
    raw_prices_data = region_price.raw_data
  end

  prices_data = JSON.parse(raw_prices_data)
  prices_with_max_threads = prices_data.map do |item|
    max_threads = AMAZON_CLOUD_DEFAULTS.calc_max_threads_per_instance(instance_type: item['instanceType'])
    item.merge(maxThreadsByInstance: max_threads, numInstances: 1)
  end

  JSON.dump(prices_with_max_threads.sort_by { |a| a['hourlyCostByInstance'] })
end
