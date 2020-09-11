# frozen_string_literal: true

require 'hailstorm/model'
require 'hailstorm/model/load_agent'
require 'hailstorm/support/file_helper'

# Models a load agent which executes JMeter in client mode
# @author Sayantam Dey
class Hailstorm::Model::MasterAgent < Hailstorm::Model::LoadAgent
  include Hailstorm::Support::FileHelper::InstanceMethods

  # Executes JMeter command appropriate to a master agent
  def start_jmeter
    logger.debug { "#{self.class}##{__method__}" }
    command_template = self.jmeter_plan.master_command(self.private_ip_address, slave_ip_addresses, self.clusterable)
    evaluate_execute(command_template)
  end

  # Stops JMeter execution if all stars are aligned correctly.
  def stop_jmeter(wait: false, aborted: false, doze_time: 60)
    logger.debug { "#{self.class}##{__method__}" }
    unless jmeter_running?
      raise(Hailstorm::Exception,
            "Jmeter is not running on #{self.identifier}##{self.public_ip_address}")
    end

    Hailstorm::Support::SSH.start(self.public_ip_address,
                                  self.clusterable.user_name,
                                  self.clusterable.ssh_options) do |ssh|
      update_pid = false
      if self.jmeter_plan.loop_forever?
        needs_term = true
      else
        needs_term, update_pid = determine_term_need(ssh, wait, aborted, doze_time)
      end

      if needs_term
        terminate_remote_jmeter(ssh, doze_time)
        update_pid = true
      end

      self.update_column(:jmeter_pid, nil) if update_pid
    end
    slaves.each(&:stop_jmeter) if self.jmeter_pid.nil?
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

    remote_file_name = self.jmeter_plan.remote_log_file(slave: false, execution_cycle: execution_cycle)
    underscored_ip_address = self.public_ip_address.tr('.', '_')
    local_file_name = remote_file_name.gsub(/\.(.+?)$/, '-')
                                      .concat(underscored_ip_address)
                                      .concat(".#{Regexp.last_match(1)}") # interpose identifier before file extn

    remote_file_path = "#{self.jmeter_plan.remote_log_dir}/#{remote_file_name}"
    local_file_path = File.join(local_log_path, local_file_name)
    local_compressed_file_path = "#{local_file_path}.gz"

    Hailstorm::Support::SSH.start(self.public_ip_address, self.clusterable.user_name,
                                  self.clusterable.ssh_options) do |ssh|

      ssh.exec!("gzip -q #{remote_file_path}") # downloading a compressed file is orders of magnitude faster than raw
      ssh.download("#{remote_file_path}.gz", local_compressed_file_path)
    end
    gunzip_file(local_compressed_file_path, local_file_path)
    local_file_name
  end

  # Checks if JMeter is running or not.
  # @return [Hailstorm::Model::MasterAgent] (self) if JMeter is running else nil
  def check_status
    status = nil
    unless self.jmeter_pid.nil?
      Hailstorm::Support::SSH.start(self.public_ip_address,
                                    self.clusterable.user_name,
                                    self.clusterable.ssh_options) do |ssh|

        status = self if ssh.process_running?(self.jmeter_pid)
      end
    end

    status
  end

  private

  def slave_ip_addresses
    slaves.collect(&:private_ip_address)
  end

  def slaves
    self.clusterable.slave_agents.where(jmeter_plan_id: self.jmeter_plan_id)
  end

  def determine_term_need(ssh, wait, aborted, doze_time)
    needs_term = false
    update_pid = false
    if ssh.process_running?(self.jmeter_pid)
      if wait # stop with wait was issued
        while ssh.process_running?(self.jmeter_pid)
          logger.info('JMeter is still running, waiting as asked...')
          sleep(doze_time)
        end
        logger.info('JMeter has exited, proceeding...')
        update_pid = true

      elsif aborted # abort command was issued
        needs_term = true

      else
        raise(Hailstorm::JMeterRunningException)
      end
    else
      update_pid = true
    end

    [needs_term, update_pid]
  end

  def terminate_remote_jmeter(ssh, doze_time)
    ssh.exec!(evaluate_command(self.jmeter_plan.stop_command))
    wait_for_shutdown(ssh, doze_time)
  end
end
