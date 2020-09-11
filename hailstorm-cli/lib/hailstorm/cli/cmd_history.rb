# frozen_string_literal: true

require 'hailstorm/cli'

# Command history for CLI
class Hailstorm::Cli::CmdHistory

  DEFAULT_MAX_HISTORY = 1000

  attr_reader :memory,
              :max_history_size

  def initialize(memory, max_history_size: DEFAULT_MAX_HISTORY)
    @memory = memory
    @max_history_size = (ENV['HAILSTORM_HISTORY_LINES'] || max_history_size).to_i
  end

  def reload_saved_history
    return unless File.exist?(saved_history_path)

    File.open(saved_history_path, 'r') do |f|
      f.each_line { |l| memory.push(l.chomp) }
    end
  end

  def saved_history_path
    File.join(java.lang.System.getProperty('user.home'), '.hailstorm_history')
  end

  def save_history(command)
    create_history_file
    command_history = read_command_history
    return command_history unless command_history.empty? || command_history.last != command

    command_history.push(command.chomp)
    if command_history.size == max_history_size
      File.open(saved_history_path, 'w') do |f|
        command_history.each { |c| f.puts(c) }
      end
    else
      File.open(saved_history_path, 'a') do |f|
        f.puts(command)
      end
    end

    command_history
  end

  def pop
    memory.pop
  end

  private

  def read_command_history
    command_history = []
    File.open(saved_history_path, 'r') do |f|
      f.each_line { |l| command_history.push(l.chomp) unless l.blank? }
    end
    command_history.shift if command_history.size == max_history_size
    command_history
  end

  def create_history_file
    FileUtils.touch(saved_history_path) unless File.exist?(saved_history_path)
  end

end
