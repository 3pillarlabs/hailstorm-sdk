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
  key_file_path = File.expand_path('../../data/keys.yml', __FILE__)
  keys = YAML.load_file(key_file_path)
  @aws.access_key = keys['access_key']
  @aws.secret_key = keys['secret_key']
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

Then(/^an AMI with name '(.+?)' should exist$/) do |ami_name|
  aws_config = @aws.send(:aws_config)
  ec2 = AWS::EC2.new(aws_config).regions[@aws.region]
  ami_names = ec2.images().with_owner(:self).select {|e| e.state == :available}.collect(&:name)
  expect(ami_names).to include(ami_name)
end

Then(/^installed JMeter version should be '(.+?)'$/) do |expected_jmeter_version|
  begin
    require 'hailstorm/model/master_agent'
    load_agent = Hailstorm::Model::MasterAgent.new
    @aws.start_agent(load_agent)
    require 'hailstorm/support/ssh'
    jmeter_version_out = nil
    Hailstorm::Support::SSH.start(load_agent.public_ip_address, @aws.user_name, @aws.ssh_options) do |ssh|
      ssh.exec!("$HOME/jmeter/bin/jmeter --version | grep '3.2'") do |ch, stream, data|
        jmeter_version_out = data if stream == :stdout
      end
    end

    expect(jmeter_version_out).to_not be_nil
    expect(jmeter_version_out).to include(expected_jmeter_version)
  ensure
    load_agent.ec2_instance.terminate() if load_agent.ec2_instance
  end
end
