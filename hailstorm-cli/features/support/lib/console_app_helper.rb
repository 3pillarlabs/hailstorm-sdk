require 'pty'

module ConsoleAppHelper

  mattr_accessor :read_fd_hailstorm_pty, :write_fd_hailstorm_pty, :pid_hailstorm_pty

  def spawn_hailstorm(script_path)
    r, w, pid = PTY.spawn(script_path)
    sleep(10)
    raise(StandardError, r.gets) unless hailstorm_spawned?(pid)
    self.class.read_fd_hailstorm_pty = r
    self.class.write_fd_hailstorm_pty = w
    self.class.pid_hailstorm_pty = pid
    # Process.detach(pid)
  end

  def hailstorm_spawned?(pid = false)
    return false unless pid || self.class.pid_hailstorm_pty
    Process.kill(0, pid || self.class.pid_hailstorm_pty) rescue false
  end

  def write_hailstorm_pty(str, no_response = false)
    self.class.write_fd_hailstorm_pty.puts(str)
    # sleep 3
    # read_hailstorm_pty unless no_response
  end

  def read_hailstorm_pty
    self.class.read_fd_hailstorm_pty.read_nonblock(4096) rescue ''
  end

  def hailstorm_exit_ok?
    _, status = Process.wait2(self.class.pid_hailstorm_pty)
    status.exited?
  rescue
    true
  end

  def exec_hailstorm(script_path)
    expect(system(script_path)).to be_true
  end
end
