include DbHelper

Given(/^Amazon is chosen as the cluster$/) do
  require 'hailstorm/application'
  require 'hailstorm/support/configuration'
  Hailstorm::Application.initialize!('aws_steps', '.', db_props, Hailstorm::Support::Configuration.new)
  require 'hailstorm/model/amazon_cloud'
  @aws = Hailstorm::Model::AmazonCloud.new()
  key_file_path = File.expand_path('../../data/keys.yml', __FILE__)
  keys = YAML.load_file(key_file_path)
  @aws.access_key = keys['access_key']
  @aws.secret_key = keys['secret_key']
end

When /^I choose '(.+?)' region$/ do |region|
  # @region_ami_map = @aws.send(:region_base_ami_map).reduce({}) do |a, e|
  #   region = e.first
  #   ami_id = e[1]['64-bit']
  #   a.merge({region => ami_id})
  # end
  @region = region
  @ami_id = @aws.send(:region_base_ami_map)[@region]['64-bit']
  expect(@ami_id).to_not be_nil
end

Then /^the AMI should exist$/ do
  aws_config = @aws.send(:aws_config)
  ec2 = AWS::EC2.new(aws_config).regions[@region]
  expect(ec2.images[@ami_id]).to exist
end
