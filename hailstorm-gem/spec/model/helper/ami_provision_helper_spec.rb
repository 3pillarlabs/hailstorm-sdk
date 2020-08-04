require 'spec_helper'
require 'hailstorm/model/helper/ami_provision_helper'

describe Hailstorm::Model::Helper::AmiProvisionHelper do
  before(:each) do
    @helper = Hailstorm::Model::Helper::AmiProvisionHelper.new(region: 'us-east-1',
                                                               user_home: '/home/ubuntu',
                                                               jmeter_version: '5.2.1')
  end

  context '#install_jmeter' do
    it 'should execute installer commands' do
      mock_ssh = double('Mock SSH')
      mock_ssh.should_receive(:exec!).at_least(:once)
      @helper.install_jmeter(mock_ssh)
    end
  end

  context '#install_java' do
    it 'should collect remote stdout' do
      @helper.stub!(:ssh_channel_exec_instr) do |_ssh, instr,  cb|
        cb.call("#{instr} ok")
        true
      end
      expect(@helper.install_java(double('ssh'))).to_not be_empty
    end

    it 'should raise error if installation fails' do
      @helper.stub!(:ssh_channel_exec_instr).and_return(nil)
      expect { @helper.install_java(double('ssh')) }
          .to raise_error(Hailstorm::JavaInstallationException) { |error| expect(error.diagnostics).to_not be_blank }
    end
  end

  context '#ssh_channel_exec_instr' do
    it 'should return instruction execution status' do
      mock_channel = double('Mock SSH Channel')
      mock_channel.stub!(:on_data).and_yield(mock_channel, 'instruction output')
      mock_channel.stub!(:on_extended_data).and_yield(mock_channel, $stderr, nil)
      mock_channel.stub!(:wait)
      mock_channel.stub!(:exec) do |&block|
        block.call(mock_channel, true)
      end
      mock_ssh = mock(Net::SSH)
      mock_ssh.stub!(:open_channel) do |&block|
        block.call(mock_channel)
        mock_channel
      end

      out = ''
      status = @helper.send(:ssh_channel_exec_instr, mock_ssh, 'ls', ->(s) { out += s.to_s })
      expect(status).to be_true
      expect(out).to_not be_empty
    end
  end
end
