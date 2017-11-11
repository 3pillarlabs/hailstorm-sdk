require 'spec_helper'
require 'yaml'

require 'hailstorm/model/amazon_cloud'
require 'hailstorm/model/project'

describe Hailstorm::Model::AmazonCloud do
  before(:each) do
    @aws = Hailstorm::Model::AmazonCloud.new
  end

  it 'maintains a mapping of AMI IDs for AWS regions' do
    @aws.send(:region_base_ami_map).should_not be_empty
  end

  context '#default_max_threads_per_agent' do
    it 'should increase with instance class and type' do
      all_results = []
      %i[:t2 :m4 :m3 :c4 :c3 :r4 :r3 :d2 :i2 :i3 :x1].each do |instance_class|
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
      project.jmeter_version = project.send(:jmeter_version_from_installer_url)
      project.send(:set_defaults)
      @aws.project = project
    end
    context '#ami_id' do
      it 'should have project_code appended to custom version' do
        expect(@aws.send(:ami_id)).to match(Regexp.new(@aws.project.project_code))
      end
    end
    context '#jmeter_download_url' do
      it 'should be same as custom jmeter installer URL' do
        expect(@aws.send(:jmeter_download_url)).to eql(@aws.project.custom_jmeter_installer_url)
      end
    end
    context '#jmeter_download_file' do
      it 'should be request path of custom jmeter installer URL' do
        expect(@aws.send(:jmeter_download_file)).to eql(@request_path)
      end
    end
    context '#jmeter_directory' do
      it 'should be file name without .tgz|.tar.gz' do
        expect(@aws.send(:jmeter_directory)).to eql(@request_name)
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
    context '#jmeter_download_url' do
      it 'should be an S3 URL' do
        expect(@aws.send(:jmeter_download_url).to_s).to match(/s3\.amazonaws\.com/)
      end
    end
    context '#jmeter_download_file' do
      it 'should be jmeter_directory.tgz' do
        expect(@aws.send(:jmeter_download_file)).to match(Regexp.new(@aws.send(:jmeter_directory)))
      end
    end
    context '#jmeter_directory' do
      it 'should be the file name without .tgz' do
        expect(@aws.send(:jmeter_directory)).to match(/apache\-jmeter/)
      end
    end
  end

  context '#setup' do
    context '#active=true' do
      it 'should be persisted' do
        aws = Hailstorm::Model::AmazonCloud.new
        aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec_8a202').first_or_create!
        aws.access_key = 'dummy'
        aws.secret_key = 'dummy'
        aws.region = 'ua-east-1'

        aws.stub(:identity_file_exists, nil)
        aws.should_receive(:identity_file_exists)

        aws.stub(:set_availability_zone, nil)
        aws.should_receive(:set_availability_zone)

        aws.stub(:create_agent_ami, nil)
        aws.should_receive(:create_agent_ami)

        aws.stub(:provision_agents, nil)
        aws.should_receive(:provision_agents)

        aws.stub(:secure_identity_file, nil)
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

        aws.stub(:identity_file_exists, nil)
        aws.should_not_receive(:identity_file_exists)

        aws.stub(:set_availability_zone, nil)
        aws.should_not_receive(:set_availability_zone)

        aws.stub(:create_agent_ami, nil)
        aws.should_not_receive(:create_agent_ami)

        aws.stub(:provision_agents, nil)
        aws.should_not_receive(:provision_agents)

        aws.stub(:secure_identity_file, nil)
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
end
