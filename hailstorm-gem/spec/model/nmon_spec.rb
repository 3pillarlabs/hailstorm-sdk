require 'spec_helper'
require 'hailstorm/model/nmon'
require 'hailstorm/model/project'
require 'hailstorm/model/execution_cycle'

describe Hailstorm::Model::Nmon do
  before(:each) do
    @nmon = Hailstorm::Model::Nmon.new(active: true, ssh_identity: 'papi',
                                       user_name: 'ubuntu', host_name: 's01', role_name: 'db')
    @nmon.project = Hailstorm::Model::Project.new(project_code: 'nmon_spec')
    @nmon.stub!(:transfer_identity_file)
    expect(@nmon).to be_valid
    @mock_ssh = mock(Net::SSH)
    Hailstorm::Support::SSH.stub!(:start).and_yield(@mock_ssh)
  end

  context '#setup' do
    context 'nmon is installed on remote machine' do
      context 'nmon is still running on remote machine' do
        it 'should terminate the remote process' do
          @mock_ssh.stub!(:file_exists?).and_return(true)
          @nmon.executable_pid = 1234
          @mock_ssh.stub!(:terminate_process)
          @nmon.setup
          expect(@nmon.executable_pid).to be_nil
        end
      end
    end
    context 'nmon is not installed on remote machine' do
      it 'should raise an error' do
        @mock_ssh.stub!(:file_exists?).and_return(false)
        expect { @nmon.setup }.to raise_error(Hailstorm::Exception)
      end
    end
  end

  context '#start_monitoring' do
    it 'should start monitoring and record the PID' do
      @nmon.project = Hailstorm::Model::Project.new(project_code: __FILE__)
      expect(@nmon.project).to respond_to(:current_execution_cycle)
      @nmon.project.stub!(:current_execution_cycle).and_return(mock(Hailstorm::Model::ExecutionCycle, id: 23))
      @mock_ssh.stub!(:directory_exists?).and_return(false)
      @mock_ssh.should_receive(:make_directory)
      @mock_ssh.should_receive(:exec!).and_return("1234\n")
      @nmon.start_monitoring
      expect(@nmon.executable_pid).to be == 1234
    end
  end

  context '#stop_monitoring' do
    before(:each) do
      @nmon.executable_pid = 1234
      @mock_ssh.stub!(:exec!)
    end
    context 'remote nmon was shutdown successfully' do
      it 'should set executable_pid = nil' do
        state_ite = [true, false].each
        @mock_ssh.stub!(:process_running?) { state_ite.next }
        @nmon.stop_monitoring(0)
        expect(@nmon.executable_pid).to be_nil
      end
    end
    context 'remote nmon was not shutdown' do
      it 'should raise error' do
        @mock_ssh.stub!(:process_running?).and_return(true)
        expect { @nmon.stop_monitoring(0) }.to raise_error(Hailstorm::Exception)
      end
    end
    context 'remote process not running' do
      it 'should do nothing' do
        @mock_ssh.stub!(:process_running?).and_return(false)
        @mock_ssh.should_not_receive(:exec!)
        @nmon.stop_monitoring
      end
    end
  end

  context '#cleanup' do
    it 'should terminate the remote process and delete the remote directory' do
      @nmon.executable_pid = 1234
      @mock_ssh.should_receive(:terminate_process)
      @mock_ssh.should_receive(:exec!).with { |cmd| expect(cmd).to match_regex(/^rm -rf/) }
      @nmon.cleanup
      expect(@nmon.executable_pid).to be_nil
    end
  end

  context '#calculate_average_stats' do
    it 'should return average cpu, memory and swap' do
      @nmon.project = Hailstorm::Model::Project.new(project_code: __FILE__)
      expect(@nmon.project).to respond_to(:current_execution_cycle)
      @nmon.project.stub!(:current_execution_cycle).and_return(mock(Hailstorm::Model::ExecutionCycle, id: 23))
      @mock_ssh.stub!(:download)
      @nmon.sampling_interval = 1
      expected_averages = [15.4181818182, 1924.416667, 1379.583333]
      log_data =<<-DATA
      CPU_ALL,CPU Total vmtuxbox,User%,Sys%,Wait%,Idle%,Busy,CPUs
      CPU_ALL,T0001,22.5,5.4,0.6,71.5,,4
      CPU_ALL,T0002,19.2,5.7,0.1,74.9,,4
      CPU_ALL,T0003,19.5,5.6,0.1,74.8,,4
      CPU_ALL,T0004,20.0,5.2,0.4,74.3,,4
      CPU_ALL,T0005,8.8,3.9,2.7,84.6,,4
      CPU_ALL,T0006,6.3,9.7,2.1,81.9,,4
      CPU_ALL,T0007,12.3,13.7,1.7,72.3,,4
      CPU_ALL,T0008,3.5,3.8,5.2,87.5,,4
      CPU_ALL,T0009,2.3,0.7,0.2,96.9,,4
      CPU_ALL,T0010,0.1,0.1,0.1,99.8,,4
      CPU_ALL,T0011,0.8,0.5,0.1,98.7,,4
      MEM,Memory MB vmtuxbox,memtotal,hightotal,lowtotal,swaptotal,memfree,highfree,lowfree,swapfree,memshared,cached,active,bigfree,buffers,swapcached,inactive
      MEM,T0001,2013.2,1159.9,853.2,2046.0,72.6,9.0,63.6,690.0,-0.0,1323.1,942.6,-1.0,181.3,0.0,845.1
      MEM,T0002,2013.2,1159.9,853.2,2046.0,72.2,8.4,63.9,660.0,-0.0,1323.5,943.4,-1.0,181.3,0.0,844.3
      MEM,T0003,2013.2,1159.9,853.2,2046.0,62.0,1.7,60.3,571.0,-0.0,1323.5,954.0,-1.0,181.3,0.0,844.3
      MEM,T0004,2013.2,1159.9,853.2,2046.0,71.6,6.5,65.1,719.0,-0.0,1323.2,946.5,-1.0,180.2,0.0,842.1
      MEM,T0005,2013.2,1159.9,853.2,2046.0,80.5,15.7,64.7,641.0,-0.0,1321.7,938.7,-1.0,180.4,0.0,841.3
      MEM,T0006,2013.2,1159.9,853.2,2046.0,80.2,15.7,64.4,737.0,-0.0,1323.7,937.1,-1.0,180.5,0.0,842.2
      MEM,T0007,2013.2,1159.9,853.2,2046.0,78.1,5.9,72.1,511.0,-0.0,1324.2,946.7,-1.0,180.6,0.0,835.1
      MEM,T0008,2013.2,1159.9,853.2,2046.0,102.3,23.0,79.3,862.0,-0.0,1311.0,938.6,-1.0,180.9,0.0,819.2
      MEM,T0009,2013.2,1159.9,853.2,2046.0,110.6,30.5,80.1,567.0,-0.0,1311.1,931.2,-1.0,181.0,0.0,817.9
      MEM,T0010,2013.2,1159.9,853.2,2046.0,110.8,30.5,80.3,574.0,-0.0,1311.1,931.3,-1.0,181.0,0.0,817.7
      MEM,T0011,2013.2,1159.9,853.2,2046.0,110.8,30.5,80.3,553.0,-0.0,1311.1,931.3,-1.0,181.0,0.0,817.7
      MEM,T0012,2013.2,1159.9,853.2,2046.0,113.7,33.4,80.3,912.0,-0.0,1311.2,928.0,-1.0,181.0,0.0,817.8
      DATA

      class IOBuffer
        attr_reader :name

        def initialize(name)
          @name = name
          @buffer = ''
          @readlines = nil
        end

        def puts(str)
          @buffer += "#{str}\n";
          @readlines = nil
        end

        def close
          @buffer.freeze
        end

        def readlines
          @readlines ||= @buffer.split("\n")
        end

        def each_line
          self.readlines.each { |line| yield line }
        end
      end
      delta = 1.0e-06
      output_streams = [IOBuffer.new(:cpu), IOBuffer.new(:mem), IOBuffer.new(:swap)]
      output_streams_ite = output_streams.each
      File.stub!(:open) do |_path, &block|
        if block
          block.call(StringIO.new(log_data.strip_heredoc))
        else
          output_streams_ite.next
        end
      end

      actual_averages = @nmon.calculate_average_stats(Time.now - 10, Time.now + 10)
      expect(actual_averages.size).to be == expected_averages.size
      (0..2).each do |index|
        expect(actual_averages[index]).to be_within(delta).of(expected_averages[index])
      end

      File.stub!(:unlink)

      cpu_stream = output_streams[0]
      expect(cpu_stream.name).to be == :cpu
      File.stub!(:open).and_return(cpu_stream)
      expect(@nmon.cpu_usage_trend).to be == cpu_stream
      File.stub!(:open).and_yield(cpu_stream)
      ok_yield = false
      @nmon.cpu_usage_trend do
        ok_yield = true
        expected_samples = [27.9, 24.9, 25.1, 25.2, 12.7, 16.0, 26.0, 7.3, 3.0, 0.2, 1.3].each
        @nmon.each_cpu_usage_sample(nil) do |actual_sample|
          expect(actual_sample).to be_within(delta).of(expected_samples.next)
        end
      end
      expect(ok_yield).to be_true

      memory_stream = output_streams[1]
      expect(memory_stream.name).to be == :mem
      File.stub!(:open).and_return(memory_stream)
      expect(@nmon.memory_usage_trend).to be == memory_stream
      File.stub!(:open).and_yield(memory_stream)
      ok_yield = false
      @nmon.memory_usage_trend do
        ok_yield = true
        expected_samples = [1940.6, 1941, 1951.2, 1941.6, 1932.7, 1933, 1935.1, 1910.9, 1902.6, 1902.4, 1902.4,
                            1899.5].each
        @nmon.each_memory_usage_sample(nil) do |actual_sample|
          expect(actual_sample).to be_within(delta).of(expected_samples.next)
        end
      end
      expect(ok_yield).to be_true

      swap_stream = output_streams[2]
      expect(swap_stream.name).to be == :swap
      File.stub!(:open).and_return(swap_stream)
      expect(@nmon.swap_usage_trend).to be == swap_stream
      File.stub!(:open).and_yield(swap_stream)
      ok_yield = false
      @nmon.swap_usage_trend do
        ok_yield = true
        expected_samples = [1356.0, 1386.0, 1475.0, 1327.0, 1405.0, 1309.0, 1535.0, 1184.0, 1479.0, 1472.0, 1493.0,
                            1134.0].each
        @nmon.each_swap_usage_sample(nil) do |actual_sample|
          expect(actual_sample).to be_within(delta).of(expected_samples.next)
        end
      end
      expect(ok_yield).to be_true
    end
  end
  
  context ':ssh_identity file not present' do
    it 'should add a validation message' do
      @nmon.unstub!(:transfer_identity_file)
      @nmon.stub!(:transfer_identity_file).and_raise(Errno::ENOENT, 'mock error')
      expect(@nmon).to_not be_valid
      expect(@nmon.errors).to include(:ssh_identity)
    end
  end

  context ':ssh_identity is absolute path' do
    it 'should transfer this file to Hailstorm FS' do
      @nmon.unstub!(:transfer_identity_file)
      @nmon.ssh_identity = '/path/to/identity.pem'
      Hailstorm.fs = mock(Hailstorm::Behavior::FileStore)
      Hailstorm.fs.should_receive(:read_identity_file).with('/path/to/identity.pem', 'nmon_spec')
      workspace = mock(Hailstorm::Support::Workspace)
      workspace.stub!(:write_identity_file)
      workspace.stub!(:identity_file_path).and_return('/path/to/identity.pem')
      Hailstorm.stub!(:workspace).and_return(workspace)
      @nmon.stub!(:secure_identity_file)
      @nmon.transfer_identity_file
    end
  end
end
