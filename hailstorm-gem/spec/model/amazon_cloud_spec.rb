require 'spec_helper'
require 'yaml'

require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/project'

describe Hailstorm::Model::AmazonCloud do

  # @param [Hailstorm::Model::AmazonCloud] aws
  def stub_aws!(aws)
    aws.stub(:identity_file_exists, nil)
    aws.stub(:set_availability_zone, nil)
    aws.stub(:create_agent_ami, nil)
    aws.stub(:provision_agents, nil)
    aws.stub(:secure_identity_file, nil)
    aws.stub(:create_security_group, nil)
  end

  before(:each) do
    @aws = Hailstorm::Model::AmazonCloud.new
  end

  it 'maintains a mapping of AMI IDs for AWS regions' do
    @aws.send(:region_base_ami_map).should_not be_empty
  end

  context '#default_max_threads_per_agent' do
    it 'should increase with instance class and type' do
      all_results = []
      %i[t2 m4 m3 c4 c3 r4 r3 d2 i2 i3 x1].each do |instance_class|
        iclass_results = []
        [:nano, :micro, :small, :medium, :large, :xlarge, '2xlarge'.to_sym, '4xlarge'.to_sym, '10xlarge'.to_sym,
         '16xlarge'.to_sym, '32xlarge'.to_sym].each do |instance_size|

          @aws.instance_type = "#{instance_class}.#{instance_size}"
          default_threads = @aws.send(:default_max_threads_per_agent)
          iclass_results << default_threads
          expect(iclass_results).to eql(iclass_results.sort)
          all_results << default_threads
        end
      end
      expect(all_results).to_not include(nil)
      expect(all_results).to_not include(0)
      expect(all_results.min).to be >= 3
      expect(all_results.max).to be <= 10000
    end
  end

  context '.round_off_max_threads_per_agent' do

    it 'should round off to the nearest 5 if <= 10' do
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(4)).to eq(5)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(5)).to eq(5)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(8)).to eq(10)
    end

    it 'should round off to the nearest 10 if <= 50' do
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(11)).to eq(10)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(15)).to eq(20)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(44)).to eq(40)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(45)).to eq(50)
    end

    it 'should round off to the nearest 50 if > 50' do
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(51)).to eq(50)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(75)).to eq(100)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(155)).to eq(150)
      expect(Hailstorm::Model::AmazonCloud.round_off_max_threads_per_agent(375)).to eq(400)
    end
  end

  context '#new' do
    it 'should be valid with the keys' do
      @aws.access_key = 'foo'
      @aws.secret_key = 'bar'
      expect(@aws).to be_valid
      expect(@aws.region).to eql('us-east-1')
    end
  end

  context 'with custom JMeter installer' do
    before(:each) do
      require 'hailstorm/model/project'
      require 'digest/sha2'
      project = Hailstorm::Model::Project.new(project_code: Digest::SHA2.new.to_s[0..5])
      @request_name = 'rhapsody-jmeter-3.2_zzz'
      @request_path = "#{@request_name}.tgz"
      project.custom_jmeter_installer_url = "http://whodunit.org/a/b/c/#{@request_path}"
      project.send(:set_defaults)
      @aws.project = project
    end
    context '#ami_id' do
      it 'should have project_code appended to custom version' do
        expect(@aws.send(:ami_id)).to match(Regexp.new(@aws.project.project_code))
      end
    end
  end

  context 'with default JMeter' do
    before(:each) do
      require 'hailstorm/model/project'
      require 'digest/sha2'
      project = Hailstorm::Model::Project.new(project_code: Digest::SHA2.new.to_s[0..5])
      project.send(:set_defaults)
      @aws.project = project
    end
    context '#ami_id' do
      it 'should only have default jmeter version' do
        expect(@aws.send(:ami_id)).to_not match(Regexp.new(@aws.project.project_code))
        expect(@aws.send(:ami_id)).to match(Regexp.new(@aws.project.jmeter_version.to_s))
      end
    end
  end

  context '#setup' do
    context '#active=true' do
      it 'should be persisted' do
        aws = Hailstorm::Model::AmazonCloud.new
        aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
        aws.access_key = 'dummy'
        aws.secret_key = 'dummy'
        aws.region = 'ua-east-1'

        stub_aws!(aws)
        aws.should_receive(:identity_file_exists)
        aws.should_receive(:set_availability_zone)
        aws.should_receive(:create_agent_ami)
        aws.should_receive(:provision_agents)
        aws.should_receive(:secure_identity_file)

        aws.active = true
        aws.setup
        expect(aws).to be_persisted
      end
    end
    context '#active=false' do
      it 'should be persisted' do
        aws = Hailstorm::Model::AmazonCloud.new
        aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec_96137').first_or_create!
        aws.access_key = 'dummy'
        aws.secret_key = 'dummy'
        aws.region = 'ua-east-1'

        stub_aws!(aws)
        aws.should_not_receive(:identity_file_exists)
        aws.should_not_receive(:set_availability_zone)
        aws.should_not_receive(:create_agent_ami)
        aws.should_not_receive(:provision_agents)
        aws.should_not_receive(:secure_identity_file)

        aws.active = false
        aws.setup
        expect(aws).to be_persisted
      end
    end
  end

  context '#ssh_options' do
    before(:each) do
      @aws.ssh_identity = 'blah'
    end
    context 'standard SSH port' do
      it 'should have :keys' do
        expect(@aws.ssh_options).to include(:keys)
      end
      it 'should not have :port' do
        expect(@aws.ssh_options).to_not include(:port)
      end
    end
    context 'non-standard SSH port' do
      before(:each) do
        @aws.ssh_port = 8022
      end
      it 'should have :keys' do
        expect(@aws.ssh_options).to include(:keys)
      end
      it 'should have :port' do
        expect(@aws.ssh_options).to include(:port)
        expect(@aws.ssh_options[:port]).to eql(8022)
      end
    end
  end

  context 'non-standard SSH ports' do
    before(:each) do
      @aws.ssh_port = 8022
      @aws.active = true
      @aws.stub(:identity_file_exists, nil) { true }
    end
    context 'agent_ami is not present' do
      it 'should raise an error' do
        @aws.valid?
        expect(@aws.errors).to include(:agent_ami)
      end
    end
    context 'agent_ami is present' do
      it 'should not raise an error' do
        @aws.agent_ami = 'fubar'
        @aws.valid?
        expect(@aws.errors).to_not include(:agent_ami)
      end
    end
  end

  context '#create_security_group' do
    before(:each) do
      @aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
      @aws.access_key = 'dummy'
      @aws.secret_key = 'dummy'
      stub_aws!(@aws)
      @aws.active = true
    end
    context 'agent_ami is not specfied' do
      it 'should be invoked' do
        @aws.should_receive(:create_security_group)
        @aws.save!
      end
    end
    context 'agent_ami is specified' do
      it 'should be invoked' do
        @aws.agent_ami = 'ami-42'
        @aws.should_receive(:create_security_group)
        @aws.save!
      end
    end
  end

  context '#create_ec2_instance' do
    before(:each) do
      @aws.stub!(:ensure_ssh_connectivity).and_return(true)
      @aws.stub!(:ssh_options).and_return({})
      @mock_instance = mock('MockInstance', id: 'A', public_ip_address: '8.8.8.4')
      mock_instance_collection = mock('MockInstanceCollection', create: @mock_instance)
      mock_ec2 = mock('MockEC2', instances: mock_instance_collection)
      @aws.stub!(:ec2).and_return(mock_ec2)
    end
    context 'when ec2_instance_ready? is true' do
      it 'should return clean_instance' do
        @aws.stub!(:ec2_instance_ready?).and_return(true)
        instance = @aws.send(:create_ec2_instance, {})
        expect(instance).to eql(@mock_instance)
      end
    end
  end

  context '#ami_creation_needed?' do
    context '#active == false' do
      it 'should return false' do
        @aws.active = false
        expect(@aws.send(:ami_creation_needed?)).to be_false
      end
    end
    context 'self.agent_ami is nil' do
      it 'should check_for_existing_ami' do
        @aws.active = true
        @aws.agent_ami = nil
        @aws.stub!(check_for_existing_ami: nil)
        @aws.should_receive(:check_for_existing_ami)
        @aws.send(:ami_creation_needed?)
      end
    end
    context 'check_for_existing_ami is not nil' do
      it 'should return false' do
        @aws.active = true
        @aws.agent_ami = nil
        @aws.stub!(:check_for_existing_ami).and_return('ami-1234')
        expect(@aws.send(:ami_creation_needed?)).to be_false
      end
    end
    context 'check_for_existing_ami is nil' do
      it 'should return true' do
        @aws.active = true
        @aws.agent_ami = nil
        @aws.stub!(:check_for_existing_ami).and_return(nil)
        expect(@aws.send(:ami_creation_needed?)).to be_true
      end
    end
  end
end
