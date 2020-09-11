# frozen_string_literal: true

require 'active_record/base'

# Model for AWS EC2 pricing data
# region (String)
# raw_data (String / text)
# next_update (DateTime)
class AwsEc2Price < ActiveRecord::Base
end
