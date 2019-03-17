require 'spec_helper'
require 'hailstorm/support/amazon_account_cleaner'
require 'aws'

describe Hailstorm::Support::AmazonAccountCleaner do

  it 'clean an AWS account of Hailstorm artifacts' do
    AWS.stub!
    account_cleaner = Hailstorm::Support::AmazonAccountCleaner.new(access_key_id: 'A', secret_access_key: 'A')
    account_cleaner.cleanup(true)
  end
end
