# frozen_string_literal: true

require 'stringio'
require 'hailstorm/model/helper/aws_region_helper'

After do |scenario|
  if scenario.source_tag_names.include?('@delete_untagged_resources') && @untagged_resource_group
    @untagged_resource_group[:instance]&.terminate
    @untagged_resource_group[:key_pair]&.delete
    @untagged_resource_group[:security_group]&.delete
  end
end

Then(/^the AMI should exist$/) do
  ec2 = ec2_resource(region: @aws.region)
  expect(ec2.images(image_ids: [@ami_id]).first).to_not be_nil
end

Then(/^an AMI with name '(.+?)' (?:should |)exists?$/) do |ami_name|
  ec2 = ec2_resource(region: @aws.region)
  avail_amis = ec2.images(owners: %w[self]).select { |e| e.state.to_sym == :available }
  ami_names = avail_amis.collect(&:name)
  expect(ami_names).to include(ami_name)
  @aws.agent_ami = avail_amis.find { |e| e.name == ami_name }.id
end

And(/^a public VPC subnet is available$/) do
  public_subnet = select_public_subnets(region: @aws.region).first
  expect(public_subnet).to_not be_nil
  @aws.vpc_subnet_id = public_subnet.id
end

And(/^there is no AMI with name '([^']+)'$/) do |ami_name|
  ec2 = ec2_resource(region: @aws.region)
  ami = ec2.images(owners: %w[self]).find { |img| img.name == ami_name }
  if ami
    snapshot_ids = ami.block_device_mappings
                      .select { |blkdev| blkdev.key?(:ebs) }
                      .map { |blkdev| blkdev[:ebs][:snapshot_id] }
    ami.deregister
    snapshot_ids.each { |snapshot_id| ec2.snapshot(snapshot_id).delete }
  end
end

Given(/^AWS untagged resources with prefix '(.+?)' in a region with a public subnet$/) do |prefix|
  region_code = feature_parameter(feature: 'clean_aws_account', param: 'region_with_public_subnet')
  public_subnet = select_public_subnets(region: region_code).first
  expect(public_subnet).to_not be_nil
  @untagged_resource_group = {
    region: region_code,
    security_group: create_security_group(region: region_code, group_name: prefix, vpc_id: public_subnet.vpc_id),
    key_pair: create_key_pair(region: region_code, key_name: prefix),
    agent_ami: find_most_recent_amazon_ami(region: region_code),
    subnet_id: public_subnet.id
  }

  expect(@untagged_resource_group[:agent_ami]).to_not be_nil
  @untagged_resource_group[:instance] = create_instances(
    params: {
      region: region_code,
      image_id: @untagged_resource_group[:agent_ami].id,
      key_name: @untagged_resource_group[:key_pair].name,
      security_group_id: @untagged_resource_group[:security_group].id,
      subnet_id: public_subnet.id
    }
  ).first
end

And(/^the AWS resources are not deleted$/) do
  raise('Expected @untagged_resource_group to be defined') if @untagged_resource_group.blank?

  expect(@untagged_resource_group[:instance].reload.state.name).to_not be == 'running'
  expect(key_pair_exists?(region: @untagged_resource_group[:region],
                          key_pair_id: @untagged_resource_group[:key_pair].key_pair_id)).to be(true)
  expect(@untagged_resource_group[:agent_ami].reload.state).to be == 'available'
  expect(security_group_exists?(region: @untagged_resource_group[:region],
                                security_group_id: @untagged_resource_group[:security_group].id)).to be(true)
end

And(/^the AWS resources are deleted as well$/) do
  args = { region: @aws.region, tags: { hailstorm: { created: true } } }
  expect(tagged_ec2_instances(args)).to be_empty
  expect(tagged_key_pairs(args)).to be_empty
  expect(tagged_images(args)).to be_empty
  expect(tagged_security_groups(args)).to be_empty
  expect(tagged_subnets(args)).to be_empty
  expect(tagged_internet_gws(args)).to be_empty
  expect(tagged_vpcs(args)).to be_empty
end

And(/^the created resources are tagged$/) do
  region_code = feature_parameter(feature: 'clean_aws_account', param: 'clean_region')
  args = { region: region_code, tags: { hailstorm: { created: true } } }
  expect(tagged_ec2_instances(args)).to_not be_empty
  expect(tagged_key_pairs(args)).to_not be_empty
  expect(tagged_images(args)).to_not be_empty
  expect(tagged_security_groups(args)).to_not be_empty
  expect(tagged_subnets(args)).to_not be_empty
  expect(tagged_internet_gws(args)).to_not be_empty
  expect(tagged_vpcs(args)).to_not be_empty
end
