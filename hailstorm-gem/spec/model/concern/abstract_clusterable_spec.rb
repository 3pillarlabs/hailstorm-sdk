# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/model/concern/abstract_clusterable'
require 'hailstorm/model/amazon_cloud'

describe Hailstorm::Model::Concern::AbstractClusterable do
  # @param [Hailstorm::Model::AmazonCloud] aws
  def stub_aws!(aws)
    allow(aws).to receive(:secure_identity_file)
    allow(aws).to receive(:create_security_group)
  end

  before(:each) do
    @aws = Hailstorm::Model::AmazonCloud.new
  end

  context '#setup' do
    before(:each) do
      @aws.project = Hailstorm::Model::Project.where(project_code: 'amazon_cloud_spec').first_or_create!
      @aws.access_key = 'dummy'
      @aws.secret_key = 'dummy'
      @aws.region = 'ua-east-1'
      stub_aws!(@aws)
    end

    context '#active=true' do
      it 'should be persisted' do
        expect(@aws).to receive(:identity_file_exists)
        expect(@aws).to receive(:set_availability_zone)
        expect(@aws).to receive(:create_agent_ami)
        expect(@aws).to receive(:provision_agents)
        expect(@aws).to receive(:assign_vpc_subnet) { @aws.vpc_subnet_id = 'subnet-1234' }

        @aws.active = true
        @aws.setup
        expect(@aws).to be_persisted
      end

      context 'vpc_subnet_id is present' do
        it 'should not create new subnet' do
          @aws.vpc_subnet_id = 'subnet-1234'
          expect(@aws).to receive(:identity_file_exists)
          expect(@aws).to receive(:set_availability_zone)
          expect(@aws).to receive(:create_agent_ami)
          expect(@aws).to receive(:provision_agents)
          expect(@aws).to_not receive(:assign_vpc_subnet)

          @aws.active = true
          @aws.setup
        end
      end
    end

    context '#active=false' do
      it 'should be persisted' do
        expect(@aws).to_not receive(:identity_file_exists)
        expect(@aws).to_not receive(:set_availability_zone)
        expect(@aws).to_not receive(:create_agent_ami)
        expect(@aws).to_not receive(:provision_agents)
        expect(@aws).to_not receive(:secure_identity_file)
        expect(@aws).to_not receive(:assign_vpc_subnet)

        @aws.active = false
        @aws.setup
        expect(@aws).to be_persisted
      end
    end
  end
end
