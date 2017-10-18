require 'spec_helper'

describe Hailstorm::Model::Nmon do
  context '#setup' do
    before(:each) do
      Hailstorm::Support::SSH.stub(:start, mock('SSH').as_null_object)
    end
    it 'should start an SSH connection' do
      nmon = Hailstorm::Model::Nmon.new(active: true, ssh_identity: 'foobar')
      Hailstorm::Support::SSH.should_receive(:start)
      nmon.setup
    end
  end
end