require 'spec_helper'

require 'hailstorm/model/slave_agent'
require 'hailstorm/model/jmeter_plan'
require 'hailstorm/model/data_center'

describe Hailstorm::Model::SlaveAgent do

  before(:each) do
    @slave_agent = Hailstorm::Model::SlaveAgent.new
  end

  it 'should be a slave' do
    expect(@slave_agent.slave?).to be true
  end

  context '#start_jmeter' do
    it 'should call #evaluate_execute' do
      @slave_agent.jmeter_plan = Hailstorm::Model::JmeterPlan.new
      expect(@slave_agent.jmeter_plan).to respond_to(:slave_command)
      command = '/bin/jmeter'
      allow(@slave_agent.jmeter_plan).to receive(:slave_command).and_return(command)
      expect(@slave_agent).to receive(:evaluate_execute).with(command)
      @slave_agent.start_jmeter
    end
  end

  context '#stop_jmeter' do
    context 'jmeter_running? == true' do
      it 'should wait_for_shutdown' do
        allow(@slave_agent).to receive(:jmeter_running?).and_return(true)
        @slave_agent.clusterable = Hailstorm::Model::DataCenter.new
        expect(@slave_agent.clusterable).to respond_to(:ssh_options)
        allow(@slave_agent.clusterable).to receive(:ssh_options).and_return({})
        allow(Hailstorm::Support::SSH).to receive(:start).and_yield(class_double(Net::SSH))
        expect(@slave_agent).to receive(:wait_for_shutdown)
        expect(@slave_agent).to receive(:update_column).with(:jmeter_pid, nil)
        @slave_agent.stop_jmeter(false, false, 0)
      end
    end
  end
end
