# frozen_string_literal: true

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

Given(/^a(?:n| previously deleted) AWS cluster is configured in (?:any|'(.+?)') region$/) do |region_code|
  require 'hailstorm/model/amazon_cloud'
  @aws = Hailstorm::Model::AmazonCloud.new
  @aws.project = @project
  @aws.access_key, @aws.secret_key = aws_keys
  @aws.region = region_code || 'ap-northeast-1'
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

Then(/^the AMI is deleted from the AWS cluster model$/) do
  if @aws
    @aws.reload
  else
    @aws = @project.clusters[0].cluster_instance
  end

  expect(@aws.agent_ami).to be_nil
end

And(/^an AWS cluster configured with these resources$/) do
  access_key, secret_key = aws_keys
  aws = create_aws_cluster(@project,
                           access_key: access_key,
                           secret_key: secret_key,
                           ssh_identity: @untagged_resource_group[:key_pair].key_name,
                           region: @untagged_resource_group[:region],
                           agent_ami: @untagged_resource_group[:agent_ami].id,
                           user_name: 'ec2-user',
                           security_group: @untagged_resource_group[:security_group].group_name,
                           instance_type: 't3a.nano',
                           max_threads_per_agent: 5,
                           vpc_subnet_id: @untagged_resource_group[:subnet_id])

  create_load_agent(aws, @untagged_resource_group[:instance])
  @project.reload
end

Given(/^an AWS cluster and resources created by Hailstorm in a clean region$/) do
  region_code = feature_parameter(feature: 'clean_aws_account', param: 'clean_region')
  @hailstorm_config.clusters('amazon_cloud') do |aws|
    aws.access_key, aws.secret_key = aws_keys
    aws.region = region_code
    aws.active = true
    aws.instance_type = 't3a.nano'
  end

  @project.settings_modified = true
  @project.setup(config: @hailstorm_config)
end
