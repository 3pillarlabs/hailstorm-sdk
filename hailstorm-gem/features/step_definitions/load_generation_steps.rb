# frozen_string_literal: true

require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/data_center'
require 'hailstorm/model/master_agent'
require 'hailstorm/support/aws_exception_builder'

include AwsHelper

Given(/^JMeter is correctly configured$/) do
  Hailstorm.fs = CukeDataFs.new if Hailstorm.fs.nil?
  @hailstorm_config.jmeter do |jmeter|
    jmeter.properties do |map|
      map['NumUsers'] = 10
      map['Duration'] = 180
    end
  end
end

Given(/^Cluster is (in|)correctly configured in '([^']+)'$/) do |incorrectly, aws_region|
  @hailstorm_config.clusters(:amazon_cloud) do |aws|
    aws.access_key, aws.secret_key = incorrectly.blank? ? aws_keys : %w[A s]
    aws.region = aws_region
  end
end


When(/^load generation fails due to a (temporary AWS failure|configuration error|temporary AWS instance failure)$/) do |failure_reason|
  @temporary_failure = /temporary/.match?(failure_reason)
  @load_agent_failure = /instance failure/.match?(failure_reason)
end


Then(/^the (?:exception|error) should (not |)suggest a time period to wait before trying again$/) do |no_retry|
  RSpec::Mocks.with_temporary_scope do
    mock_aws_error = double('Aws::Errors::ServiceError', message: 'mock_error', retryable?: @temporary_failure)
    aws_exception = Hailstorm::Support::AwsExceptionBuilder.from(mock_aws_error)
    fail_once = true
    fail_once_lock = Mutex.new
    if @load_agent_failure
      allow_any_instance_of(Hailstorm::Model::MasterAgent).to receive(:execute_jmeter_command) do |agent|
        agent.update_column(:jmeter_pid, 123_456)
      end

      allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:create_agent_ami) do |amz_cloud|
        amz_cloud.agent_ami = 'ami-03cbb521ac9517d1e'
      end

      allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:assign_vpc_subnet) do |amz_cloud|
        amz_cloud.vpc_subnet_id = 'subnet-1234'
      end

      allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:create_security_group)

      allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:start_agent) do |_amz_cloud, _load_agent|
        fail_once_lock.synchronize do
          if fail_once
            fail_once = false
            raise(aws_exception)
          end
        end
      end
    else
      allow_any_instance_of(Hailstorm::Model::AmazonCloud).to receive(:identity_file_exists).and_raise(aws_exception)
    end

    begin
      @project.settings_modified = true
      @project.start(config: @hailstorm_config)
    rescue StandardError => error
      real_error = error.is_a?(Hailstorm::ThreadJoinException) ? error.exceptions.first : error

      if no_retry.blank?
        expect(real_error).to be_retryable
      else
        expect(real_error).to_not be_retryable
      end
    end
  end
end

Given(/^each cluster has (\d+) load agents$/) do |agent_count|
  threads_per_agent = Hailstorm::Model::Helper::AmazonCloudDefaults.calc_max_threads_per_instance(
    instance_type: Hailstorm::Model::Helper::AmazonCloudDefaults::INSTANCE_TYPE
  )

  @hailstorm_config.jmeter do |jmeter|
    jmeter.properties do |map|
      map['NumUsers'] = threads_per_agent * agent_count
      map['Duration'] = 180
    end
  end
end

Then(/^the other load agents should still be created$/) do
  expect(@project.load_agents.count).to be_positive
end

Given(/^Data center is correctly configured with multiple agents$/) do
  @hailstorm_config.clusters(:data_center) do |cluster|
    cluster.machines = %w[172.20.2.31 172.20.2.17 172.20.2.18]
    cluster.user_name = 'joe'
    cluster.ssh_identity = 'hailstorm.pem'
    cluster.title = 'one'
  end
end

When(/^load generation fails on one agent due to (missing Java or incorrect version|unreachable agent|missing JMeter or incorrect version)$/) do |error_kind|
  @data_center_error = case error_kind
                       when /missing Java or incorrect version/
                         Hailstorm::DataCenterJavaFailure.new('1.6')
                       when /unreachable agent/
                         Hailstorm::DataCenterAccessFailure.new('joe',
                                                                '172.20.2.31',
                                                                'hailstorm.pem')
                       when /missing JMeter or incorrect version/
                         Hailstorm::DataCenterJMeterFailure.new('1.8')
                       else
                         Hailstorm::Exception.new('unknown error')
                       end
end

Then(/^other agents should be configured and saved$/) do
  RSpec::Mocks.with_temporary_scope do
    expect(@project).to_not receive(:configure_target_hosts)
    allow_any_instance_of(Hailstorm::Model::DataCenter).to receive(:identity_file_ok).and_return(nil)
    allow_any_instance_of(Hailstorm::Model::MasterAgent).to receive(:upload_scripts)
    fail_once = true
    fail_once_lock = Mutex.new
    if @data_center_error
      allow_any_instance_of(Hailstorm::Model::DataCenter).to receive(:agent_before_save_on_create) do
        fail_once_lock.synchronize do
          if fail_once
            fail_once = false
            raise(@data_center_error)
          end
        end
      end
    end

    begin
      @project.settings_modified = true
      @project.start(config: @hailstorm_config)
    rescue Hailstorm::Exception => error
      real_error = error.is_a?(Hailstorm::ThreadJoinException) ? error.exceptions.first : error
      expect(real_error).to eql(@data_center_error)
      expect(real_error.diagnostics).to_not be_blank
    end

    expect(@project.load_agents.count).to be == 2
  end
end
