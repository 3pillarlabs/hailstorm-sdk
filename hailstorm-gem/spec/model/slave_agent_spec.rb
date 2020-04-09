require 'spec_helper'

require 'hailstorm/model/slave_agent'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/data_center'

describe Hailstorm::Model::SlaveAgent do

  before(:each) do
    @slave_agent = Hailstorm::Model::SlaveAgent.new
  end

  it 'should be a slave' do
    expect(@slave_agent.slave?).to be_true
  end

  context '#start_jmeter' do
    it 'should call #evaluate_execute' do
      @slave_agent.jmeter_plan = Hailstorm::Model::JmeterPlan.new
      expect(@slave_agent.jmeter_plan).to respond_to(:slave_command)
      command = '/bin/jmeter'
      @slave_agent.jmeter_plan.stub!(:slave_command).and_return(command)
      @slave_agent.should_receive(:evaluate_execute).with(command)
      @slave_agent.start_jmeter
    end
  end

  context '#stop_jmeter' do
    context 'jmeter_running? == true' do
      it 'should wait_for_shutdown' do
        @slave_agent.stub!(:jmeter_running?).and_return(true)
        @slave_agent.clusterable = Hailstorm::Model::DataCenter.new
        expect(@slave_agent.clusterable).to respond_to(:ssh_options)
        @slave_agent.clusterable.stub!(:ssh_options).and_return({})
        Hailstorm::Support::SSH.stub!(:start).and_yield(mock(Net::SSH))
        @slave_agent.should_receive(:wait_for_shutdown)
        @slave_agent.should_receive(:update_column).with(:jmeter_pid, nil)
        @slave_agent.stop_jmeter(false, false, 0)
      end
    end
  end
end
