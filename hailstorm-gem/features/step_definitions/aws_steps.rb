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

When /^I choose the following regions$/ do |table|
  @checked = {}
  @region_ami_map = @aws.send(:region_base_ami_map)
  table.hashes.each do |row|
    region = row['region']
    ami_id = @region_ami_map[region]['64-bit']
    aws_config = @aws.send(:aws_config)
    ec2 = AWS::EC2.new(aws_config).regions[region]
    @checked[ami_id] = ec2.images[ami_id].exists?
  end
end

Then /^the AMI should exist$/ do
  expect(@checked.values.count {|e| e == true}).to eq(@checked.values.length)
end
