require 'spec_helper'
require 'yaml'

require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::AmazonCloud do
  before(:all) do
    @aws = Hailstorm::Model::AmazonCloud.new()
  end

  it 'maintains a mapping of AMI IDs for AWS regions' do
    @aws.send(:region_base_ami_map).should_not be_empty
  end
end
