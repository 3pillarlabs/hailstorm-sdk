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

  context '#default_max_threads_per_agent' do
    it 'should increase with instance class and type' do
      all_results = []
      [:t2, :m4, :m3, :c4, :c3, :r4, :r3, :d2, :i2, :i3, :x1].each do |instance_class|
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
end
