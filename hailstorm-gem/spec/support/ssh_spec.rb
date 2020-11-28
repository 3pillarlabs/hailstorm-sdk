# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/support/ssh'

describe Hailstorm::Support::SSH do
  before(:each) do
    @mock_net_ssh = Net::SSH::Connection::Session.new(spy('transport'))
  end

  context '.start' do
    context 'block given' do
      it 'should yield extended Net::SSH instance' do
        allow(Net::SSH).to receive(:start).and_yield(@mock_net_ssh)
        Hailstorm::Support::SSH.start('example.com', 'ubuntu') do |ssh|
          expect(ssh).to be_kind_of(Hailstorm::Support::SSH::ConnectionSessionInstanceMethods)
        end
      end
    end

    context 'no block given' do
      it 'should return extended Net::SSH instance' do
        allow(Net::SSH).to receive(:start).and_return(@mock_net_ssh)
        ssh = Hailstorm::Support::SSH.start('example.com', 'ubuntu')
        expect(ssh).to be_kind_of(Hailstorm::Support::SSH::ConnectionSessionInstanceMethods)
      end
    end

    context 'when first attempt fails' do
      before(:each) do
        @ssh_attempt = proc do
          Hailstorm::Support::SSH.start('example.com', 'ubuntu', retry_limit: 5, retry_base_delay: 0)
        end
      end

      context 'connection established within maximum attempts' do
        it 'should not raise error' do
          failures = [IOError, nil].each
          allow(Net::SSH).to receive(:start) do
            failure_reason = failures.next
            raise(failure_reason) if failure_reason

            @mock_net_ssh
          end

          expect(@ssh_attempt).to_not raise_error
        end
      end

      context 'connection not established after maximum attempts' do
        it 'should raise error' do
          allow(Net::SSH).to receive(:start).and_raise(IOError)
          expect(@ssh_attempt).to raise_error
        end
      end
    end
  end

  context Hailstorm::Support::SSH::ConnectionSessionInstanceMethods do
    before(:each) do
      allow(Net::SSH).to receive(:start).and_return(@mock_net_ssh)
      @ssh = Hailstorm::Support::SSH.start('example.com', 'ubuntu')
    end

    context '#file_exists?' do
      it 'should be true if remote file exists, false otherwise' do
        mock_channel = instance_double(Net::SSH::Connection::Channel)
        allow(@ssh).to receive(:exec!).and_yield(mock_channel, :stdout, 'foobar')
        expect(@ssh.file_exists?('foobar')).to be true

        allow(@ssh).to receive(:exec!).and_yield(mock_channel, :stderr, 'foobar does not exist')
        expect(@ssh.file_exists?('foobar')).to be false
      end
    end

    context '#directory_exists?' do
      it 'should be true if directory exists, false otherwise' do
        mock_channel = instance_double(Net::SSH::Connection::Channel)
        allow(@ssh).to receive(:exec!).and_yield(mock_channel, :stdout, 'foobar')
        expect(@ssh.directory_exists?('foobar')).to be true

        allow(@ssh).to receive(:exec!).and_yield(mock_channel, :stderr, 'foobar does not exist')
        expect(@ssh.directory_exists?('foobar')).to be false
      end
    end

    context '#process_running?' do
      it 'should be true if PID is found in remote process table' do
        pid = 10_023
        remote_processes = [instance_double(Hailstorm::Support::SSH::RemoteProcess, pid: pid)]
        allow(@ssh).to receive(:remote_processes).and_return(remote_processes)
        expect(@ssh.process_running?(pid)).to be true
        expect(@ssh.process_running?(90_024)).to be false
      end
    end

    context '#terminate_process' do
      it 'should signal the running process' do
        states = [true, true, true, false].each
        allow(@ssh).to receive(:process_running?) { states.next }
        expect(@ssh).to receive(:exec!).exactly(3).times
        @ssh.terminate_process(123, 0)
      end
    end

    context '#terminate_process_tree' do
      it 'should terminate parent and child processes up to any depth' do
        process_ary = [
          { ppid: 10, pid: 20, cmd: 'gen 1' },
          { ppid: 20, pid: 30, cmd: 'gen 2-1' },
          { ppid: 20, pid: 40, cmd: 'gen 2-2' },
          { ppid: 30, pid: 50, cmd: 'gen 3' },
          { ppid: 40, pid: 60, cmd: 'gen 4' }
        ].map { |x| Hailstorm::Support::SSH::RemoteProcess.new(x) }
        allow(@ssh).to receive(:remote_processes).and_return(process_ary)
        expect(@ssh).to receive(:terminate_process).exactly(5).times
        @ssh.terminate_process_tree(20, 0)
      end
    end

    context '#make_directory' do
      it 'should create remote directory if it is not present' do
        allow(@ssh).to receive(:directory_exists?).and_return(false)
        expect(@ssh).to receive(:exec!)
        @ssh.make_directory('/tmp/foo')
      end
    end

    context 'sftp subsystem' do
      before(:each) do
        @local = '/foo/bar'
        @remote = '/baz/bar'
        @mock_sftp = instance_double(Net::SFTP::Session)
        allow(@ssh).to receive(:sftp).and_return(@mock_sftp)
      end

      context '#upload' do
        it 'should delegate to sftp sub system' do
          expect(@mock_sftp).to receive(:upload!).with(@local, @remote)
          @ssh.upload(@local, @remote)
        end

        it 'should try again on failure' do
          failures = [IOError, nil].each
          allow(@mock_sftp).to receive(:upload!) do
            failure = failures.next
            raise(failure) if failure
          end

          expect { @ssh.upload(@local, @remote, retry_base_delay: 0, retry_limit: 2) }.to_not raise_error
        end

        it 'should fail after maximum attempts are over' do
          allow(@mock_sftp).to receive(:upload!).and_raise(IOError)
          expect { @ssh.upload(@local, @remote, retry_base_delay: 0, retry_limit: 2) }.to raise_error
        end
      end

      context '#download' do
        it 'should delegate to sftp sub system' do
          expect(@mock_sftp).to receive(:download!).with(@remote, @local)
          @ssh.download(@remote, @local)
        end

        it 'should try again on failure' do
          failures = [IOError, nil].each
          allow(@mock_sftp).to receive(:download!) do
            failure = failures.next
            raise(failure) if failure
          end

          expect { @ssh.download(@remote, @local, retry_base_delay: 0, retry_limit: 2) }.to_not raise_error
        end

        it 'should fail after maximum attempts are over' do
          allow(@mock_sftp).to receive(:download!).and_raise(IOError)
          expect { @ssh.download(@remote, @local, retry_base_delay: 0, retry_limit: 2) }.to raise_error
        end
      end
    end

    context '#find_process_id' do
      it 'should find the process id in remote process table' do
        allow(@ssh).to receive(:remote_processes).and_return(
          [Hailstorm::Support::SSH::RemoteProcess.new(cmd: 'grep foo', pid: 1234, ppid: 123)]
        )

        expect(@ssh.find_process_id('grep')).to be == 1234
        expect(@ssh.find_process_id('find')).to be_nil
      end
    end

    context '#remote_processes' do
      it 'should fetch the remote process table for logged in user' do
        data = <<-SAMPLE
        PID  PPID CMD
        2202  1882 /bin/sh /usr/bin/startkde
        2297  2202 /usr/bin/ssh-agent /usr/bin/gpg-agent --daemon --sh --write-env-file=/home/sa
        2298  2202 /usr/bin/gpg-agent --daemon --sh --write-env-file=/home/sayantamd/.gnupg/gpg-
        2301     1 /usr/bin/dbus-launch --exit-with-session /usr/bin/startkde
        2302     1 /bin/dbus-daemon --fork --print-pid 5 --print-address 7 --session
        SAMPLE
        allow(@ssh).to receive(:options).and_return({ user: 'ubuntu' })
        allow(@ssh).to receive(:exec!).and_yield(instance_double(Net::SSH::Connection::Session), :stdout, data)
        rows = @ssh.remote_processes
        expect(rows.size).to be == 5
        expect(rows[0].to_h).to be == { pid: 2202, ppid: 1882, cmd: '/bin/sh /usr/bin/startkde' }
      end
    end

    context '#exec' do
      it 'should be aliased to net_ssh_exec' do
        expect(@ssh).to receive(:net_ssh_exec)
        @ssh.exec('ls')
      end

      it 'should try again on failure' do
        failures = [IOError, nil].each
        allow(@ssh).to receive(:net_ssh_exec) do
          failure = failures.next
          raise(failure) if failure
        end

        expect { @ssh.exec('ls', retry_base_delay: 0, retry_limit: 2) }.to_not raise_error
      end

      it 'should fail after maximum attempts are over' do
        allow(@ssh).to receive(:exec).and_raise(IOError)
        expect { @ssh.exec('ls', retry_base_delay: 0, retry_limit: 2) }.to raise_error
      end
    end
  end
end
