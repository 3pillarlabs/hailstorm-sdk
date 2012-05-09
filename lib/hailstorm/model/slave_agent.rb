# Models a load agent which acts as a slave load agent. A load agent can be 
# a slave in two cases - JMeter is operating in master-slave model or concurrent
# slave model.
# @author Sayantam Dey

require 'hailstorm/model'
require 'hailstorm/model/load_agent'

class Hailstorm::Model::SlaveAgent < Hailstorm::Model::LoadAgent

  # Executes JMeter command appropriate to a slave agent
  def start_jmeter()
    
    logger.debug { "#{self.class}##{__method__}" }
    command_template = self.jmeter_plan.slave_command(self.private_ip_address)
    logger.debug(command_template)
    command = evaluate_command(command_template)
    logger.debug(command)
    execute_jmeter_command(command)
  end

  def stop_jmeter()

    logger.debug { "#{self.class}##{__method__}" }
    if jmeter_running?()
      Hailstorm::Support::SSH.start(self.public_ip_address,
                                    self.clusterable.user_name, self.clusterable.ssh_options) do |ssh|

        ssh.terminate_process(self.jmeter_pid)
        self.update_column(:jmeter_pid, nil)
      end
    end
  end

  # A slave agent is a "slave". Overrides LoadAgent#is_slave?
  def slave?
    true
  end


end
