# frozen_string_literal: true

require 'hailstorm/model/helper/aws_region_helper'
require 'hailstorm/model/helper/amazon_cloud_defaults'

# AWS Region Helper
module AwsRegionHelper

  # @return [Hailstorm::Model::Helper::AwsRegionHelper]
  def aws_region_helper
    @aws_region_helper ||= Hailstorm::Model::Helper::AwsRegionHelper.new
  end

  def aws_regions
    aws_region_helper.aws_regions_graph
  end

  def default_region_node
    aws_region_helper.region_node(code: Hailstorm::Model::Helper::AmazonCloudDefaults::EC2_REGION)
  end
end
