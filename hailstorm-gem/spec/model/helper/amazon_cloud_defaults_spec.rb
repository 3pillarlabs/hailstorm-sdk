require 'spec_helper'
require 'hailstorm/model/helper/amazon_cloud_defaults'

describe Hailstorm::Model::Helper::AmazonCloudDefaults do
  context '.max_threads_per_agent' do
    it 'should round off to the nearest 5 if <= 10' do
      expect(described_class.max_threads_per_agent(4)).to eq(5)
      expect(described_class.max_threads_per_agent(5)).to eq(5)
      expect(described_class.max_threads_per_agent(8)).to eq(10)
    end

    it 'should round off to the nearest 10 if <= 50' do
      expect(described_class.max_threads_per_agent(11)).to eq(10)
      expect(described_class.max_threads_per_agent(15)).to eq(20)
      expect(described_class.max_threads_per_agent(44)).to eq(40)
      expect(described_class.max_threads_per_agent(45)).to eq(50)
    end

    it 'should round off to the nearest 50 if > 50' do
      expect(described_class.max_threads_per_agent(51)).to eq(50)
      expect(described_class.max_threads_per_agent(75)).to eq(100)
      expect(described_class.max_threads_per_agent(155)).to eq(150)
      expect(described_class.max_threads_per_agent(375)).to eq(400)
    end
  end
end
