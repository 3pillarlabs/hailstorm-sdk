require 'spec_helper'
require 'hailstorm/support/ssh'

describe Hailstorm::Support::SSH do

  context '.start' do
    before(:each) do
      @mock_net_ssh = mock(Net::SSH)
      @mock_net_ssh.should_receive(:logger=)
    end
    context 'block given' do
      it 'should yield extended Net::SSH instance' do
        Net::SSH.stub!(:start).and_yield(@mock_net_ssh)
        Hailstorm::Support::SSH.start('example.com', 'ubuntu') do |ssh|
          expect(ssh).to be_kind_of(Hailstorm::Support::SSH::ConnectionSessionInstanceMethods)
        end
      end
    end

    context 'no block given' do
      it 'should return extended Net::SSH instance' do
        Net::SSH.stub!(:start).and_return(@mock_net_ssh)
        ssh = Hailstorm::Support::SSH.start('example.com', 'ubuntu')
        expect(ssh).to be_kind_of(Hailstorm::Support::SSH::ConnectionSessionInstanceMethods)
      end
    end
  end

  context '.ensure_connection' do
    before(:each) do
      @mock_net_ssh = mock(Net::SSH)
      Hailstorm::Support::SSH.stub!(:start).and_yield(@mock_net_ssh)
    end
    context 'connect established' do
      it 'should return true' do
        @mock_net_ssh.stub!(:exec!)
        expect(Hailstorm::Support::SSH.ensure_connection('example.com', 'ubuntu')).to be_true
      end
    end

    context 'connection not established in first attempt but within maximum attempts' do
      it 'should return true' do
        states = [Errno::ECONNREFUSED, Net::SSH::ConnectionTimeout, true].each
        @mock_net_ssh.stub!(:exec!) do
          state = states.next
          raise(state) unless state.kind_of?(TrueClass)
        end
        expect(Hailstorm::Support::SSH.ensure_connection('example.com', 'ubuntu',
                                                         max_tries: 5,
                                                         doze_time: 0)).to be_true
      end
    end

    context 'connection not established after maximum attempts' do
      it 'should return false' do
        @mock_net_ssh.stub!(:exec!).and_raise(Errno::ECONNREFUSED)
        expect(Hailstorm::Support::SSH.ensure_connection('example.com', 'ubuntu', doze_time: 0)).to be_false
      end
    end
  end

  context Hailstorm::Support::SSH::ConnectionSessionInstanceMethods do
    before(:each) do
      mock_net_ssh = mock(Net::SSH)
      class << mock_net_ssh
        attr_accessor :logger
      end
      Net::SSH.stub!(:start).and_return(mock_net_ssh)
      @ssh = Hailstorm::Support::SSH.start('example.com', 'ubuntu')
    end

    context '#file_exists?' do
      it 'should be true if remote file exists, false otherwise' do
        @ssh.stub!(:exec!).and_yield(double('Channel'), :stdout, 'foobar')
        expect(@ssh.file_exists?('foobar')).to be_true

        @ssh.stub!(:exec!).and_yield(double('Channel'), :stderr, 'foobar does not exist')
        expect(@ssh.file_exists?('foobar')).to be_false
      end
    end
    
    context '#directory_exists?' do
      it 'should be true if directory exists, false otherwise' do
        @ssh.stub!(:exec!).and_yield(double('Channel'), :stdout, 'foobar')
        expect(@ssh.directory_exists?('foobar')).to be_true

        @ssh.stub!(:exec!).and_yield(double('Channel'), :stderr, 'foobar does not exist')
        expect(@ssh.directory_exists?('foobar')).to be_false
      end
    end

    context '#process_running?' do
      it 'should be true if PID is found in remote process table' do
        pid = 10023
        @ssh.stub!(:remote_processes).and_return([double('Process', pid: pid)])
        expect(@ssh.process_running?(pid)).to be_true
        expect(@ssh.process_running?(90024)).to be_false
      end
    end
    
    context '#terminate_process' do
      it 'should signal the running process' do
        states = [true, true, true, false].each
        @ssh.stub!(:process_running?) { states.next }
        @ssh.should_receive(:exec!).exactly(3).times
        @ssh.terminate_process(123, 0)
      end
    end

    context '#terminate_process_tree' do
      it 'should terminate parent and child processes up to any depth' do
        process_ary = [
          { ppid: 10, pid: 20 },
          { ppid: 20, pid: 30 },
          { ppid: 20, pid: 40 },
          { ppid: 30, pid: 50 },
          { ppid: 40, pid: 60 },
        ].map { |x| OpenStruct.new(x) }
        @ssh.stub!(:remote_processes).and_return(process_ary)
        @ssh.should_receive(:terminate_process).exactly(5).times
        @ssh.terminate_process_tree(20, 0)
      end
    end

    context '#make_directory' do
      it 'should create remote directory if it is not present' do
        @ssh.stub!(:directory_exists?).and_return(false)
        @ssh.should_receive(:exec!)
        @ssh.make_directory('/tmp/foo')
      end
    end
    
    context '#upload' do
      it 'should delegate to sftp sub system' do
        local, remote = %w[/foo/bar /baz/bar]
        mock_sftp = double('SFTP')
        @ssh.stub!(:sftp).and_return(mock_sftp)
        mock_sftp.should_receive(:upload!).with(local, remote)
        @ssh.upload(local, remote)
      end
    end

    context '#download' do
      it 'should delegate to sftp sub system' do
        local, remote = %w[/foo/bar /baz/bar]
        mock_sftp = double('SFTP')
        @ssh.stub!(:sftp).and_return(mock_sftp)
        mock_sftp.should_receive(:download!).with(remote, local)
        @ssh.download(remote, local)
      end
    end

    context '#find_process_id' do
      it 'should find the process id in remote process table' do
        @ssh.stub!(:remote_processes).and_return([OpenStruct.new(cmd: 'grep foo', pid: 1234)])
        expect(@ssh.find_process_id('grep')).to be == 1234
        expect(@ssh.find_process_id('find')).to be_nil
      end
    end

    context '#remote_processes' do
      it 'should fetch the remote process table for logged in user' do
        data =<<-SAMPLE
        PID  PPID CMD
        2202  1882 /bin/sh /usr/bin/startkde
        2297  2202 /usr/bin/ssh-agent /usr/bin/gpg-agent --daemon --sh --write-env-file=/home/sa
        2298  2202 /usr/bin/gpg-agent --daemon --sh --write-env-file=/home/sayantamd/.gnupg/gpg-
        2301     1 /usr/bin/dbus-launch --exit-with-session /usr/bin/startkde
        2302     1 /bin/dbus-daemon --fork --print-pid 5 --print-address 7 --session
        SAMPLE
        @ssh.stub!(:options).and_return({user: 'ubuntu'})
        @ssh.stub!(:exec!).and_yield(double('Channel'), :stdout, data)
        rows = @ssh.remote_processes
        expect(rows.size).to be == 5
        expect(rows[0].to_h).to be == { pid: 2202, ppid: 1882, cmd: '/bin/sh /usr/bin/startkde' }
      end
    end

    context '#exec' do
      it 'should be aliased to net_ssh_exec' do
        @ssh.should_receive(:net_ssh_exec)
        @ssh.exec('ls')
      end
    end
  end
end
