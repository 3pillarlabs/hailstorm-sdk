Given(/^Amazon is chosen as the cluster$/) do
  require 'hailstorm/application'
  Hailstorm::Application.initialize!('aws_steps', '.', {adapter: 'jdbcsqlite3', database: '/tmp/aws_steps.db'})
  require 'hailstorm/model/amazon_cloud'
  @aws = Hailstorm::Model::AmazonCloud.new()
  key_file_path = File.expand_path('../../data/keys.yml', __FILE__)
  keys = YAML.load_file(key_file_path)
  @aws.access_key = keys['access_key']
  @aws.secret_key = keys['secret_key']
end

When /^I choose a region$/ do
  @region_ami_map = @aws.send(:region_base_ami_map).reduce({}) do |a, e|
    region = e.first
    ami_id = e[1]['64-bit']
    a.merge({region => ami_id})
  end
end

Then /^(?:the AMI should exist |)for '(.+?)'$/ do |region|
  ami_id = @region_ami_map[region]
  expect(ami_id).to_not be_nil
  aws_config = @aws.send(:aws_config)
  ec2 = AWS::EC2.new(aws_config).regions[region]
  expect(ec2.images[ami_id]).to exist
end
