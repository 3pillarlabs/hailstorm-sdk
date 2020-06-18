include AwsHelper

Given(/^Amazon is chosen as the cluster$/) do
  require 'hailstorm/model/amazon_cloud'
  @aws = Hailstorm::Model::AmazonCloud.new
  @aws.project = @project
  @aws.access_key, @aws.secret_key = aws_keys
  @aws.active = true
end


When /^I choose '(.+?)' region$/ do |region|
  @aws.region = region
  @ami_id = @aws.send(:region_base_ami_map)[@aws.region]['64-bit']
  expect(@ami_id).to_not be_nil
end


Then /^the AMI should exist$/ do
  ec2 = @aws.send(:ec2, true).ec2
  expect(ec2.images[@ami_id]).to exist
end


When(/^(?:I |)create the AMI$/) do
  expect(@aws).to be_valid
  @aws.create_security_group
  @aws.send(:create_agent_ami)
end


Then(/^an AMI with name '(.+?)' (?:should |)exists?$/) do |ami_name|
  ec2 = @aws.send(:ec2, true).ec2
  avail_amis = ec2.images.with_owner(:self).select {|e| e.state == :available}
  ami_names = avail_amis.collect(&:name)
  expect(ami_names).to include(ami_name)
  @aws.agent_ami = avail_amis.find {|e| e.name == ami_name}.id
end


Then(/^installed JMeter version should be '(.+?)'$/) do |expected_jmeter_version|
  require 'hailstorm/support/ssh'
  jmeter_version_out = ''
  Hailstorm::Support::SSH.start((@load_agent || @ec2_instance).public_ip_address, @aws.user_name, @aws.ssh_options) do |ssh|
    ssh.exec!("$HOME/jmeter/bin/jmeter --version") do |_ch, stream, data|
      jmeter_version_out << data if stream == :stdout
    end
  end

  expect(jmeter_version_out).to_not be_blank
  expect(jmeter_version_out).to include(expected_jmeter_version)
end


When(/^I (?:create|start) a new load agent$/) do
  expect(@aws).to be_valid
  require 'hailstorm/model/master_agent'
  @load_agent = Hailstorm::Model::MasterAgent.new
  @aws.start_agent(@load_agent)
end


Then(/^custom properties should be added$/) do
  require 'hailstorm/support/ssh'
  require 'tmpdir'
  remote_jmeter_props_file = File.join(Dir.tmpdir, 'user.properties')
  Hailstorm::Support::SSH.start(@load_agent.public_ip_address, @aws.user_name, @aws.ssh_options) do |ssh|
    ssh.download("/home/#{@aws.user_name}/jmeter/bin/user.properties", remote_jmeter_props_file)
  end
  remote_jmeter_props = File.readlines(remote_jmeter_props_file).collect(&:chomp)
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.hostname=true')
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.thread_counts=true')
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.output_format=xml')
end


After do |scenario|
  if scenario.source_tag_names.include?('@terminate_instance')
    if @load_agent
      ec2 = @aws.send(:ec2, true).ec2
      ec2_instance = ec2.instances[@load_agent.identifier]
      ec2_instance.terminate if ec2_instance
      @aws.cleanup
    end
  end
end


Then(/^the AMI to be created would be named '(.+?)'$/) do |expected_ami_name|
  actual_ami_name = @aws.send(:ami_id)
  expect(actual_ami_name).to eq(expected_ami_name)
end


And(/^a public VPC subnet is available$/) do
  ec2 = @aws.send(:ec2, true).ec2
  public_subnet = ec2.vpcs.collect(&:subnets).flatten.collect(&:to_a).flatten.find do |sn|
    sn.route_table.routes.find {|r| r.internet_gateway && r.internet_gateway.id != 'local'}
  end

  expect(public_subnet).to_not be_nil
  @aws.vpc_subnet_id = public_subnet.id
  @aws.send(:ec2).vpc_subnet_id = @aws.vpc_subnet_id
end


And(/^instance type is '(.+?)'$/) do |instance_type|
  @aws.instance_type = instance_type
end


And(/^there is no AMI with name '([^']+)'$/) do |ami_name|
  ec2 = @aws.send(:ec2, true).ec2
  ami = ec2.images.with_owner('self').find { |img| img.name == ami_name }
  if ami
    snapshot_ids = ami.block_devices.select { |blkdev| blkdev.key?(:ebs) }.map { |blkdev| blkdev[:ebs][:snapshot_id] }
    ami.delete
    snapshot_ids.each { |snapshot_id| ec2.snapshots[snapshot_id].delete }
  end
end
