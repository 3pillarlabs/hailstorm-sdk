# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/model/helper/ami_helper'
require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/project'

describe Hailstorm::Model::Helper::AmiHelper do
  before(:each) do
    @aws = Hailstorm::Model::AmazonCloud.new
    @mock_sg_finder = instance_double(Hailstorm::Model::Helper::SecurityGroupFinder)
    @mock_ec2_helper = instance_double(Hailstorm::Model::Helper::Ec2InstanceHelper)
    @mock_instance_client = instance_double(Hailstorm::Behavior::AwsAdaptable::InstanceClient)
    @mock_ami_client = instance_double(Hailstorm::Behavior::AwsAdaptable::AmiClient)
    client_group = Hailstorm::Model::Helper::AmiHelper::ClientGroup.new(instance_client: @mock_instance_client,
                                                                        ami_client: @mock_ami_client)

    helper_group = Hailstorm::Model::Helper::AmiHelper::MemberHelperGroup.new(security_group_finder: @mock_sg_finder,
                                                                              ec2_instance_helper: @mock_ec2_helper)

    @helper = Hailstorm::Model::Helper::AmiHelper.new(client_group: client_group,
                                                      helper_group: helper_group,
                                                      aws_clusterable: @aws)
  end

  it 'maintains a mapping of AMI IDs for AWS regions' do
    expect(@helper.region_base_ami_map).to_not be_empty
  end

  context '#create_agent_ami' do
    context 'ami_creation_needed? == true' do
      before(:each) do
        @aws.active = true
        @aws.project = Hailstorm::Model::Project.create!(project_code: 'amazon_cloud_spec')
        @aws.ssh_identity = 'secure'
        @aws.instance_type = 'm1.small'
        @aws.region = 'us-east-1'
        @aws.security_group = 'sg-12345'
        @aws.vpc_subnet_id = 'subnet-1234'

        allow(@helper).to receive(:ami_creation_needed?).and_return(true)

        mock_security_group = Hailstorm::Behavior::AwsAdaptable::SecurityGroup.new(group_id: @aws.security_group)
        allow(@mock_sg_finder).to receive(:find_security_group).and_return(mock_security_group)

        mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(
          instance_id: 'i-23456',
          public_ip_address: '10.34.56.45',
          private_ip_address: '172.16.0.10',
          state: Hailstorm::Behavior::AwsAdaptable::InstanceState.new(name: 'shutting-down')
        )

        allow(@mock_ec2_helper).to receive(:create_ec2_instance).and_return(mock_instance)

        allow(@mock_instance_client).to receive(:terminated?).and_return(true)
        allow(@mock_instance_client).to receive(:ready?).and_return(true)
        allow(@helper).to receive(:provision)
      end

      context 'ami build fails' do
        it 'should raise an exception' do
          allow(@helper).to receive(:register_hailstorm_ami).and_raise(StandardError, 'mocked exception')
          expect(@mock_instance_client).to receive(:terminate)
          expect { @helper.create_agent_ami! }.to raise_error
        end
      end

      context 'ami build succeeds' do
        it 'should assign the AMI id' do
          mock_ec2_image = Hailstorm::Behavior::AwsAdaptable::Ami.new(image_id: 'ami-12334',
                                                                      state: 'available',
                                                                      name: 'same_owner/other_image')
          allow(@helper).to receive(:register_hailstorm_ami).and_return(mock_ec2_image.id)
          expect(@mock_instance_client).to receive(:terminate)
          @helper.create_agent_ami!
          expect(@aws.agent_ami).to eql(mock_ec2_image.id)
        end
      end

      context 'AWS region does not have a default base AMI' do
        before(:each) do
          @aws.region = 'where_the_regions_have_no_ami'
        end

        context 'base_ami is provided' do
          before(:each) do
            @aws.base_ami = 'ami-1234'
          end

          it 'should fail if the provided base_ami is not available in AWS' do
            allow(@mock_ami_client).to receive(:available?).and_return(false)
            error_message = "AMI #{@aws.base_ami} not available in AWS region #{@aws.region}"
            expect { @helper.create_agent_ami! }.to raise_error(Hailstorm::Exception, error_message)
          end

          it 'should use the provided base_ami instead of the default' do
            allow(@mock_ami_client).to receive(:available?).and_return(true)
            expect(@mock_ec2_helper).to receive(:create_ec2_instance).with(ami_id: @aws.base_ami,
                                                                           security_group_ids: @aws.security_group)
            allow(@helper).to receive(:build_ami)
            allow(@helper).to receive(:terminate_instance)
            @helper.create_agent_ami!
          end
        end

        context 'base_ami is not provided' do
          it 'should fail to create the agent AMI' do
            expect { @helper.create_agent_ami! }.to raise_error(Hailstorm::Exception)
          end
        end
      end
    end
  end

  context '#check_for_existing_ami' do
    context 'an AMI exists' do
      it 'should assign the AMI id to agent_ami' do
        @aws.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
        mock_ec2_ami = Hailstorm::Behavior::AwsAdaptable::Ami.new(state: 'available',
                                                                  name: @helper.send(:ami_id),
                                                                  ami_id: 'ami-123')
        allow(@mock_ami_client).to receive(:find_self_owned).and_return(mock_ec2_ami)
        @helper.send(:check_for_existing_ami)
        expect(@aws.agent_ami).to be == mock_ec2_ami.id
      end
    end
  end

  context '#ami_creation_needed?' do
    context '#active == false' do
      it 'should return false' do
        @aws.active = false
        expect(@helper.send(:ami_creation_needed?)).to be false
      end
    end

    context 'self.agent_ami is nil' do
      it 'should check_for_existing_ami' do
        @aws.active = true
        @aws.agent_ami = nil
        expect(@helper).to receive(:check_for_existing_ami).and_return(nil)
        @helper.send(:ami_creation_needed?)
      end
    end

    context 'check_for_existing_ami is not nil' do
      it 'should return false' do
        @aws.active = true
        @aws.agent_ami = nil
        allow(@helper).to receive(:check_for_existing_ami).and_return('ami-1234')
        expect(@helper.send(:ami_creation_needed?)).to be false
      end
    end

    context 'check_for_existing_ami is nil' do
      it 'should return true' do
        @aws.active = true
        @aws.agent_ami = nil
        allow(@helper).to receive(:check_for_existing_ami).and_return(nil)
        expect(@helper.send(:ami_creation_needed?)).to be true
      end
    end
  end

  context '#provision' do
    it 'should install Hailstorm dependencies on the ec2 instance' do
      @aws.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
      mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(public_ip_address: '120.34.35.58')
      mock_ssh = class_double(Net::SSH)
      allow(Hailstorm::Support::SSH).to receive(:start).and_yield(mock_ssh)
      expect_any_instance_of(Hailstorm::Model::Helper::AmiProvisionHelper).to receive(:install_java).with(mock_ssh)
      expect_any_instance_of(Hailstorm::Model::Helper::AmiProvisionHelper).to receive(:install_jmeter).with(mock_ssh)
      allow(@aws).to receive(:identity_file_path).and_return(__FILE__)
      @helper.send(:provision, mock_instance)
    end
  end

  context '#register_hailstorm_ami' do
    before(:each) do
      @aws.project = Hailstorm::Model::Project.create!(project_code: __FILE__)
      @mock_instance = Hailstorm::Behavior::AwsAdaptable::Instance.new(instance_id: 'i-67678')
    end

    it 'should create an AMI from the instance state' do
      mock_ami = Hailstorm::Behavior::AwsAdaptable::Ami.new(state: 'available', image_id: 'ami-123', name: 'hailstorm')
      allow(@mock_ami_client).to receive(:register_ami).and_return(mock_ami.id)
      allow(@mock_ami_client).to receive(:available?).and_return(true)
      ami_id = @helper.send(:register_hailstorm_ami, @mock_instance)
      expect(ami_id).to eql(mock_ami.image_id)
    end

    context 'on failure' do
      before(:each) do
        allow(@mock_ami_client).to receive(:register_ami).and_return('ami-123')
        state_reason = Hailstorm::Behavior::AwsAdaptable::StateReason.new(code: '10',
                                                                          message: 'mock AMI creation failure')
        mock_ami = Hailstorm::Behavior::AwsAdaptable::Ami.new(state: 'failed',
                                                              image_id: 'ami-123',
                                                              name: 'hailstorm',
                                                              state_reason: state_reason)
        allow(@mock_ami_client).to receive(:find).and_return(mock_ami)
      end

      it 'should raise exception' do
        allow(@helper).to receive(:wait_for).and_raise(Hailstorm::Exception, 'mock waiter error')
        expect { @helper.send(:register_hailstorm_ami, @mock_instance) }.to raise_error(Hailstorm::AmiCreationFailure)
        begin
          @helper.send(:register_hailstorm_ami, @mock_instance)
        rescue Hailstorm::AmiCreationFailure => e
          expect(e.diagnostics).to_not be_blank
        end
      end

      context 'when failure is temporary' do
        it 'should have a retryable predicated exception' do
          failure = Hailstorm::AwsException.new('mock waiter error')
          failure.retryable = true
          allow(@helper).to receive(:wait_for).and_raise(failure)
          expect { @helper.send(:register_hailstorm_ami, @mock_instance) }.to raise_error(Hailstorm::AmiCreationFailure)
          begin
            @helper.send(:register_hailstorm_ami, @mock_instance)
          rescue Hailstorm::AmiCreationFailure => error
            expect(error).to be_retryable
          end
        end
      end

      context 'when the current operation can not be retried' do
        it 'should have an non retryable predicated exception' do
          failure = Hailstorm::AwsException.new('mock waiter error')
          failure.retryable = false
          allow(@helper).to receive(:wait_for).and_raise(failure)
          expect { @helper.send(:register_hailstorm_ami, @mock_instance) }.to raise_error(Hailstorm::AmiCreationFailure)
          begin
            @helper.send(:register_hailstorm_ami, @mock_instance)
          rescue Hailstorm::AmiCreationFailure => error
            expect(error).to_not be_retryable
          end
        end
      end
    end
  end

  context '#ami_id' do
    before(:each) do
      require 'hailstorm/model/project'
      require 'digest/sha2'
      @aws.project = Hailstorm::Model::Project.new(project_code: Digest::SHA2.new.to_s[0..5])
    end
    context 'with custom JMeter installer' do
      it 'should have project_code appended to custom version' do
        request_name = 'rhapsody-jmeter-3.2_zzz'
        request_path = "#{request_name}.tgz"
        @aws.project.custom_jmeter_installer_url = "http://whodunit.org/a/b/c/#{request_path}"
        @aws.project.send(:set_defaults)
        expect(@helper.send(:ami_id)).to match(Regexp.new(@aws.project.project_code))
      end
    end
    context 'with default JMeter' do
      it 'should only have default jmeter version' do
        @aws.project.send(:set_defaults)
        expect(@helper.send(:ami_id)).to_not match(Regexp.new(@aws.project.project_code))
        expect(@helper.send(:ami_id)).to match(Regexp.new(@aws.project.jmeter_version.to_s))
      end
    end
  end
end
