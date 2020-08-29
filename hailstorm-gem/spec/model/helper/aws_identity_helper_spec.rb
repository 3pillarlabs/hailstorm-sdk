require 'spec_helper'
require 'hailstorm/model/helper/aws_identity_helper'

describe Hailstorm::Model::Helper::AwsIdentityHelper do

  context 'identity_file_path does not exist' do
    before(:each) do
      allow(File).to receive(:exist?).and_return(false)
      @mock_key_pair_client = instance_double(Hailstorm::Behavior::AwsAdaptable::KeyPairClient)
      @helper = Hailstorm::Model::Helper::AwsIdentityHelper.new(identity_file_path: '/dev/null',
                                                                ssh_identity: 'secure',
                                                                key_pair_client: @mock_key_pair_client)
      @mock_key_pair = Hailstorm::Behavior::AwsAdaptable::KeyPair.new(key_material: 'A', key_name: 'mock_key_pair')
    end

    context 'ec2 key_pair exists' do
      it 'should add an error on ssh_identity' do
        allow(@mock_key_pair_client).to receive(:find).and_return(@mock_key_pair)
        expect(@mock_key_pair_client).to receive(:delete)
        expect(@helper).to receive(:create_key_pair)
        @helper.validate_or_create_identity
      end
    end

    context 'ec2 key_pair does not exist' do
      it 'should create the ec2 key_pair' do
        allow(@mock_key_pair_client).to receive(:find).and_return(nil)
        allow(@mock_key_pair_client).to receive(:create).and_return(@mock_key_pair)
        expect(@mock_key_pair).to receive(:private_key)
        allow(File).to receive(:chmod)
        @helper.validate_or_create_identity
      end
    end
  end
end
