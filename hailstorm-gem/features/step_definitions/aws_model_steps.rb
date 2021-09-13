# frozen_string_literal: true

include ModelHelper

After do |scenario|
  if scenario.source_tag_names.include?('@terminate_instance') && @aws
    if @load_agent
      terminate_agents(@aws.region, @load_agent)
    elsif @project
      terminate_agents(@aws.region, *@project.load_agents)
    end

    @aws.cleanup
  end
end

Given(/^Amazon is chosen as the cluster$/) do
  require 'hailstorm/model/amazon_cloud'
  @aws = Hailstorm::Model::AmazonCloud.new
  @aws.project = @project
  @aws.access_key, @aws.secret_key = aws_keys
  @aws.active = true
end

When(/^I choose '(.+?)' region$/) do |region|
  @aws.region = region
  aws_region_helper = Hailstorm::Model::Helper::AwsRegionHelper.new
  @ami_id = aws_region_helper.region_base_ami_map[@aws.region]
  expect(@ami_id).to_not be_nil
end

When(/^(?:I |)create the AMI$/) do
  expect(@aws).to be_valid
  @aws.send(:create_security_group)
  @aws.send(:create_agent_ami)
end

Then(/^the AMI to be created would be named '(.+?)'$/) do |expected_ami_name|
  actual_ami_name = @aws.send(:ami_id)
  expect(actual_ami_name).to eq(expected_ami_name)
end

And(/^instance type is '(.+?)'$/) do |instance_type|
  @aws.instance_type = instance_type
end

Given(/^an AWS cluster already exists in '(.+?)' region$/) do |region_code|
  require 'hailstorm/model/amazon_cloud'
  @aws = Hailstorm::Model::AmazonCloud.new
  @aws.project = @project
  @aws.access_key, @aws.secret_key = aws_keys
  @aws.region = region_code
  @aws.active = false
  @aws.agent_ami = 'ami-123'
  @aws.save!
  @aws.update_column(:active, true)

  require 'hailstorm/model/cluster'
  Hailstorm::Model::Cluster.create!(project: @project,
                                    cluster_type: @aws.class.name,
                                    clusterable_id: @aws.id)
end

When(/^the AWS cluster is purged$/) do
  @project.purge_clusters
end

Then(/^the AWS cluster should be removed$/) do
  @aws.reload
  expect(@aws.agent_ami).to be_nil
end
