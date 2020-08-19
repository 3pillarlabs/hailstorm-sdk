require 'hailstorm/model'
require 'hailstorm/model/load_agent'

# Models a load agent which acts as a slave load agent. A load agent can be
# a slave in two cases - JMeter is operating in master-slave model or concurrent
# slave model.
# @author Sayantam Dey
class Hailstorm::Model::SlaveAgent < Hailstorm::Model::LoadAgent

  # Executes JMeter command appropriate to a slave agent
  def start_jmeter
    logger.debug { "#{self.class}##{__method__}" }
    command_template = self.jmeter_plan.slave_command(self.private_ip_address, self.clusterable)
    evaluate_execute(command_template)
  end

  def stop_jmeter(_wait = false, _aborted = false, doze_time = 60)
    logger.debug { "#{self.class}##{__method__}" }
    return unless jmeter_running?

    ssh_args = [self.public_ip_address, self.clusterable.user_name, self.clusterable.ssh_options]
    Hailstorm::Support::SSH.start(*ssh_args) do |ssh|
      # Since the master is configured to send the slaves a shutdown message,
      # we wait for graceful shutdown.
      wait_for_shutdown(ssh, doze_time)
      self.update_column(:jmeter_pid, nil)
    end
  end

  # A slave agent is a "slave". Overrides LoadAgent#is_slave?
  def slave?
    true
  end
end
