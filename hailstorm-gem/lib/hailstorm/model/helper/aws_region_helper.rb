# frozen_string_literal: true

require 'yaml'

require 'hailstorm/model/helper'

# Helper for AWS regions
class Hailstorm::Model::Helper::AwsRegionHelper

  attr_reader :aws_regions_graph,
              :region_base_ami_map

  def initialize(data: nil, memoize: true)
    data = self.class.load_data(data: data, memoize: memoize)
    @aws_regions_graph = data.aws_regions_graph
    @region_base_ami_map = data.region_base_ami_map
  end

  # @param [String] code
  def region_node(code:)
    region_node = aws_regions_graph.flat_map { |region_group| region_group['regions'] }
                                   .find { |node| node['code'] == code }

    region_node ? region_node.symbolize_keys : nil
  end

  def self.load_data(data: nil, memoize: true)
    return @data_query if @data_query && memoize

    region_data = data || YAML.load_file(File.expand_path('../aws_region_data.yml', __FILE__)).freeze
    @data_query = DataQuery.new(region_data)
    @data_query
  end

  # Query methods around region data
  class DataQuery
    attr_reader :region_data

    # @param [Hash] region_data
    def initialize(region_data)
      @region_data = region_data
    end

    def aws_regions_graph
      @aws_regions_graph ||= region_data.map do |region_group|
        node = region_group.slice('code', 'title')
        node['regions'] = region_group['regions'].map { |region| region.slice('code', 'title') }
        node
      end.freeze
    end

    def region_base_ami_map
      @region_base_ami_map ||= region_data.flat_map { |region_group| region_group['regions'] }
                                          .reduce({}) { |s, region| s.merge(region['code'] => region['ami']) }
                                          .freeze
    end
  end
end
