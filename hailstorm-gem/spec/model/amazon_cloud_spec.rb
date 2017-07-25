require 'spec_helper'
require 'yaml'

require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::AmazonCloud do
  before(:all) do
    @aws = Hailstorm::Model::AmazonCloud.new()
    key_file_path = File.expand_path('../../keys.yml', __FILE__)
    if File.exists?(key_file_path)
      keys = YAML.load_file(key_file_path)
      @aws.access_key = keys['access_key']
      @aws.secret_key = keys['secret_key']
    end
    @region_ami_map = @aws.send(:region_base_ami_map)
  end

  it "maintains a mapping of AMI IDs for AWS regions" do
    @region_ami_map.should_not be_empty
  end

  it "recognizes 14 AWS regions" do
    expect(@region_ami_map.keys.length).to eq(14) 
  end

  ["us-east-1", "us-east-2", "us-west-1", "us-west-2", "ca-central-1", "eu-west-1", "eu-central-1",
    "eu-west-2", "ap-northeast-1", "ap-southeast-1", "ap-southeast-2", "ap-northeast-2",
    "ap-south-1", "sa-east-1"].each do |region|

    it "maintains existing AMI for region #{region}", :integration do
      ami_id = @region_ami_map[region]['64-bit']
      if @aws.access_key and @aws.secret_key
        aws_config = @aws.send(:aws_config)
        ec2 = AWS::EC2.new(aws_config).regions[region]
        expect(ec2.images[ami_id]).to exist
      else
        pending('Amazon credentials not set up')
      end
    end
  end
end
