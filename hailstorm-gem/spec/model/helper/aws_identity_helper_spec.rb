require 'spec_helper'
require 'hailstorm/model/helper/aws_identity_helper'

describe Hailstorm::Model::Helper::AwsIdentityHelper do

  context 'identity_file_path does not exist' do
    before(:each) do
      File.stub!(:exist?).and_return(false)
      @mock_key_pair_client = mock(Hailstorm::Behavior::AwsAdaptable::KeyPairClient)
      @helper = Hailstorm::Model::Helper::AwsIdentityHelper.new(identity_file_path: '/dev/null',
                                                                ssh_identity: 'secure',
                                                                key_pair_client: @mock_key_pair_client)
      @mock_key_pair = Hailstorm::Behavior::AwsAdaptable::KeyPair.new(key_material: 'A', key_name: 'mock_key_pair')
    end

    context 'ec2 key_pair exists' do
      it 'should add an error on ssh_identity' do
        @mock_key_pair_client.stub!(:find).and_return(@mock_key_pair)
        @mock_key_pair_client.should_receive(:delete)
        @helper.should_receive(:create_key_pair)
        @helper.validate_or_create_identity
      end
    end

    context 'ec2 key_pair does not exist' do
      it 'should create the ec2 key_pair' do
        @mock_key_pair_client.stub!(:find).and_return(nil)
        @mock_key_pair_client.stub!(:create).and_return(@mock_key_pair)
        @mock_key_pair.should_receive(:private_key)
        File.stub!(:chmod)
        @helper.validate_or_create_identity
      end
    end
  end
end
