# Models a load agent which executes JMeter in client mode
# @author Sayantam Dey

require 'hailstorm/model'
require 'hailstorm/model/load_agent'

class Hailstorm::Model::MasterAgent < Hailstorm::Model::LoadAgent

  GZ_READ_LEN_BYTES = 2 * 1024 * 1024 # 2MB

  # Executes JMeter command appropriate to a master agent
  def start_jmeter()
    
    logger.debug { "#{self.class}##{__method__}" }
    command_template = self.jmeter_plan.master_command(self.private_ip_address,
                                                       slave_ip_addresses())
    unless command_template.nil?
      logger.debug(command_template)
      command = evaluate_command(command_template)
      logger.debug(command)
      execute_jmeter_command(command)
    end
  end

  # Stops JMeter execution if all stars are aligned correctly.
  def stop_jmeter(wait = false, aborted = false)

    logger.debug { "#{self.class}##{__method__}" }
    if jmeter_running?()
      Hailstorm::Support::SSH.start(self.public_ip_address,
                                    self.clusterable.user_name, self.clusterable.ssh_options) do |ssh|

        terminate_okay = false
        update_pid = false
        unless self.jmeter_plan.loop_forever?
          if ssh.process_running?(self.jmeter_pid)
            if wait # stop with wait was issued
              while ssh.process_running?(self.jmeter_pid)
                logger.info("JMeter is still running, waiting as asked...")
                sleep(60)
              end
              logger.info("JMeter has exited, proceeding...")
              update_pid = true

            elsif aborted # abort command was issued
              terminate_okay = true

            else
              logger.warn("Jmeter is still running! Please abort if you really mean to stop.")
            end
          else
            update_pid = true
          end

        else
          terminate_okay = true
        end

        if terminate_okay
          ssh.terminate_process(self.jmeter_pid)
          update_pid = true
        end

        self.update_column(:jmeter_pid, nil) if update_pid
      end
      if self.jmeter_pid.nil?
        slaves.each {|slave| slave.stop_jmeter() }
      end
    else
      logger.warn("Jmeter is not running on #{self.identifier}##{self.public_ip_address}")
    end
  end

  # A master agent is a "master". Overrides LoadAgent#master?
  def master?
    true
  end
  
  # Downloads the result file for execution_cycle to local_log_path.
  # @param [Hailstorm::Model::ExecutionCycle] execution_cycle
  # @param [String] local_log_path downloads file to this path
  # @return [String] name of downloaded (local) file 
  def result_for(execution_cycle, local_log_path)
    
    logger.debug { "#{self.class}##{__method__}" }
    
    remote_file_name = self.jmeter_plan.remote_log_file(false, execution_cycle)
    underscored_ip_address = self.public_ip_address.gsub('.', '_')
    local_file_name = remote_file_name.gsub(/\.(.+?)$/, '-')
                                      .concat(underscored_ip_address)
                                      .concat(".#{$1}") # interpose identifier before file extn
                                      
    remote_file_path = [self.jmeter_plan.remote_log_dir, remote_file_name].join('/')
    local_file_path = File.join(local_log_path, local_file_name)
    local_compressed_file_path = "#{local_file_path}.gz"

    Hailstorm::Support::SSH.start(self.public_ip_address, self.clusterable.user_name,
      self.clusterable.ssh_options) do |ssh|

      ssh.exec!("gzip -q #{remote_file_path}") # Research-604
      ssh.download("#{remote_file_path}.gz", local_compressed_file_path)
    end
    File.open(local_file_path, 'w') do |uncompressed_file|
      File.open(local_compressed_file_path, 'r') do |compressed_file|
        gz = Zlib::GzipReader.new(compressed_file)
        until ((bytes = gz.read(GZ_READ_LEN_BYTES))).nil?
          uncompressed_file.print(bytes)
        end
        gz.close()
      end
    end
    File.unlink(local_compressed_file_path)

    return local_file_name    
  end

  # Checks if JMeter is running or not.
  # @return [Hailstorm::Model::MasterAgent] (self) if JMeter is running else nil
  def check_status()

    status = nil
    unless self.jmeter_pid.nil?
      Hailstorm::Support::SSH.start(self.public_ip_address,
                                    self.clusterable.user_name,
                                    self.clusterable.ssh_options) do |ssh|

        status = self if ssh.process_running?(self.jmeter_pid)
      end
    end

    return status
  end

  private

  def slave_ip_addresses
    slaves().collect(&:private_ip_address)
  end

  def slaves
    self.clusterable().slave_agents().where(:jmeter_plan_id => self.jmeter_plan_id)
  end

end