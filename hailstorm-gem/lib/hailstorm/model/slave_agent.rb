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
    logger.debug(command_template)
    command = evaluate_command(command_template)
    logger.debug(command)
    execute_jmeter_command(command)
  end

  def stop_jmeter(_wait = false, _aborted = false)
    logger.debug { "#{self.class}##{__method__}" }
    return unless jmeter_running?
    Hailstorm::Support::SSH.start(self.public_ip_address,
                                  self.clusterable.user_name, self.clusterable.ssh_options) do |ssh|

      # Since the master is configured to send the slaves a shutdown message,
      # we wait for graceful shutdown.
      tries = 0
      until tries >= 3
        sleep(60)
        break unless ssh.process_running?(self.jmeter_pid)
        tries += 1
      end
      if tries >= 3
        # graceful shutdown is not happening
        ssh.terminate_process_tree(self.jmeter_pid)
      end
      self.update_column(:jmeter_pid, nil)
    end
  end

  # A slave agent is a "slave". Overrides LoadAgent#is_slave?
  def slave?
    true
  end
end
