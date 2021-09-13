# frozen_string_literal: true

require 'stringio'
require 'hailstorm/model/helper/aws_region_helper'

include AwsHelper

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
