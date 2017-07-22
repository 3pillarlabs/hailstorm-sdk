require 'spec_helper'

require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::AmazonCloud do
  it "maintains a mapping of AMI IDs for AWS regions" do
    ec2 = Hailstorm::Model::AmazonCloud.new()
    region_ami_map = ec2.send(:region_base_ami_map)
    region_ami_map.should_not be_empty
  end
end
