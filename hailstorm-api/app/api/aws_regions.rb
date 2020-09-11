# frozen_string_literal: true

require 'sinatra'
require 'helpers/aws_region_helper'

include AwsRegionHelper

get '/aws_regions' do
  JSON.dump(regions: aws_regions, defaultRegion: { code: 'us-east-1', title: 'US East (Northern Virginia)' })
end
