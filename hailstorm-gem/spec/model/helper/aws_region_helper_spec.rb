# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/model/helper/aws_region_helper'

describe Hailstorm::Model::Helper::AwsRegionHelper do
  context 'structural expectations' do
    before(:each) do
      @helper = described_class.new
    end

    it 'should present an AWS region hierarchy' do
      # @type [Enumerable] graph
      graph = @helper.aws_regions_graph
      expect(graph).to_not be_empty
      expect(graph.all? { |region_group| region_group.keys.sort == %w[code regions title] }).to be true
    end

    it 'should present code and title in AWS regions' do
      graph = @helper.aws_regions_graph
      expect(graph).to_not be_empty
      graph.each do |node|
        expect(node[:regions.to_s]).to_not be_empty
        expect(node[:regions.to_s].all? { |region| region.keys.sort == %w[code title] }).to be true
      end
    end

    it 'should present region and AMI map' do
      # @type [Hash] map
      map = @helper.region_base_ami_map
      expect(map).to_not be_empty
      expect(map).to_not have_value(nil)
    end

    it 'should memoize AWS region graph' do
      graph1 = @helper.aws_regions_graph
      graph2 = @helper.aws_regions_graph
      expect(graph1).to equal(graph2)
    end

    it 'should memoize region AMI map' do
      map1 = @helper.region_base_ami_map
      map2 = @helper.region_base_ami_map
      expect(map1).to equal(map2)
    end
  end

  context 'data expectations' do
    before(:each) do
      @data = [
        {
          code: 'North America',
          title: 'North America',
          regions: [
            { code: 'us-east-1', title: 'US East (Northern Virginia)', ami: 'ami-07ebfd5b3428b6f4d' }.stringify_keys,
            { code: 'us-west-1', title: 'US West (Northern California)', ami: 'ami-03ba3948f6c37a4b0' }.stringify_keys
          ]
        },
        {
          code: 'Europe',
          title: 'Europe',
          regions: [
            { code: 'eu-west-1', title: 'Europe (Ireland)', ami: 'ami-035966e8adab4aaad' }.stringify_keys
          ]
        }
      ].map(&:stringify_keys)

      @helper = described_class.new(data: @data, memoize: false)
    end

    it 'should have all grouped regions' do
      graph = @helper.aws_regions_graph
      expect(graph.size).to be == @data.size
      graph.each_with_index do |node, index|
        expect(node['code']).to be == @data[index]['code']
        expect(node['title']).to be == @data[index]['title']
        expect(node['regions']).to eql(@data[index]['regions'].map { |e| e.slice('code', 'title') })
      end
    end

    it 'should have AMI mapped to region code' do
      map = @helper.region_base_ami_map
      expect(map[@data[0]['regions'][0]['code']]).to be == @data[0]['regions'][0]['ami']
      expect(map[@data[0]['regions'][1]['code']]).to be == @data[0]['regions'][1]['ami']
      expect(map[@data[1]['regions'][0]['code']]).to be == @data[1]['regions'][0]['ami']
    end

    it 'should present a region node' do
      node = @helper.region_node(code: 'us-west-1')
      expect(node).to eql({ code: 'us-west-1', title: 'US West (Northern California)' })
      expect(@helper.region_node(code: 'unknown_region')).to be_nil
    end
  end
end
