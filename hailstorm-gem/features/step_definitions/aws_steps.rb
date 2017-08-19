include DbHelper

Given(/^Hailstorm is initialized with a project '(.+?)'$/) do |project_code|
  require 'hailstorm/application'
  require 'hailstorm/support/configuration'
  Hailstorm::Application.new.create_project('/tmp', 'aws_steps', true, '/vagrant/hailstorm-gem')
  Hailstorm::Application.initialize!('aws_steps', '/tmp/aws_steps/config/boot.rb', db_props, Hailstorm::Support::Configuration.new)
  require 'hailstorm/model/project'
  @project = Hailstorm::Model::Project.new()
  @project.project_code = project_code
end

Given(/^Amazon is chosen as the cluster$/) do
  require 'hailstorm/model/amazon_cloud'
  @aws = Hailstorm::Model::AmazonCloud.new()
  @aws.project = @project
  @aws.access_key, @aws.secret_key = aws_keys()
  @aws.active = true
end

When /^I choose '(.+?)' region$/ do |region|
  @aws.region = region
  @ami_id = @aws.send(:region_base_ami_map)[@aws.region]['64-bit']
  expect(@ami_id).to_not be_nil
end

Then /^the AMI should exist$/ do
  aws_config = @aws.send(:aws_config)
  ec2 = AWS::EC2.new(aws_config).regions[@aws.region]
  expect(ec2.images[@ami_id]).to exist
end

When(/^(?:I |)create the AMI$/) do
  expect(@aws).to be_valid
  @aws.send(:create_agent_ami)
end

When(/^the JMeter version for the project is '(.+?)'$/) do |jmeter_version|
  @project.jmeter_version = jmeter_version
end

Then(/^an AMI with name '(.+?)' (?:should |)exists?$/) do |ami_name|
  aws_config = @aws.send(:aws_config)
  ec2 = AWS::EC2.new(aws_config).regions[@aws.region]
  avail_amis = ec2.images().with_owner(:self).select { |e| e.state == :available }
  ami_names = avail_amis.collect(&:name)
  expect(ami_names).to include(ami_name)
  @aws.agent_ami = avail_amis.find {|e| e.name == ami_name}.id
end

Then(/^installed JMeter version should be '(.+?)'$/) do |expected_jmeter_version|
  require 'hailstorm/support/ssh'
  jmeter_version_out = nil
  Hailstorm::Support::SSH.start(@load_agent.public_ip_address, @aws.user_name, @aws.ssh_options) do |ssh|
    ssh.exec!("$HOME/jmeter/bin/jmeter --version | grep '3.2'") do |ch, stream, data|
      jmeter_version_out = data if stream == :stdout
    end
  end

  expect(jmeter_version_out).to_not be_nil
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
  remote_jmeter_props_file = File.join(Dir.tmpdir, 'jmeter.properties')
  Hailstorm::Support::SSH.start(@load_agent.public_ip_address, @aws.user_name, @aws.ssh_options) do |ssh|
    ssh.download("/home/#{@aws.user_name}/jmeter/bin/jmeter.properties", remote_jmeter_props_file)
  end
  remote_jmeter_props = File.readlines(remote_jmeter_props_file).collect(&:chomp)
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.hostname=true')
  expect(remote_jmeter_props).to include('jmeter.save.saveservice.thread_counts=true')
end

After do |scenario|
  if scenario.source_tag_names.include?('@terminate_instance')
    if @load_agent
      @load_agent.ec2_instance.terminate() if @load_agent.ec2_instance
      @aws.cleanup()
    end
  end
end

When(/^(?:the |)[jJ][mM]eter installer URL for the project is '(.+?)'$/) do |jmeter_installer_url|
  @project.custom_jmeter_installer_url = jmeter_installer_url
  @project.jmeter_version = @project.send(:jmeter_version_from_installer_url)
end

Then(/^the AMI to be created would be named '(.+?)'$/) do |expected_ami_name|
  actual_ami_name = @aws.send(:ami_id)
  expect(actual_ami_name).to eq(expected_ami_name)
end
