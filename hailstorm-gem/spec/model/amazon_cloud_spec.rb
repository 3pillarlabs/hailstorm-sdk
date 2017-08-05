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
end
