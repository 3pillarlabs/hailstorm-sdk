require 'hailstorm/middleware'
require 'hailstorm/behavior/loggable'

# Common command execution template
class Hailstorm::Middleware::CommandExecutionTemplate

  include Hailstorm::Behavior::Loggable

  attr_reader :model_delegate

  def initialize(new_model_delegate)
    @model_delegate = new_model_delegate
  end

  # Sets up the load agents and targets.
  # Creates the load agents as needed and pushes the Jmeter scripts to the agents.
  # Pushes the monitoring artifacts to targets.
  def setup(*args)
    force = args.empty? ? false : true
    model_delegate.setup(force)
  end

  # Starts the load generation and monitoring on targets
  def start(*args)
    logger.info('Starting load generation and monitoring on targets...')
    redeploy = args.empty? ? false : true
    model_delegate.start(redeploy)
  end

  # Stops the load generation and monitoring on targets and collects all logs
  def stop(*args)
    logger.info('Stopping load generation and monitoring on targets...')
    wait = args.include?('wait')
    options = { suspend: true } if args.include?('suspend')
    model_delegate.stop(wait, options)
  end

  def abort(*args)
    logger.info('Aborting load generation and monitoring on targets...')
    options = { suspend: true } if args.include?('suspend')
    model_delegate.abort(options)
  end

  def terminate(*_args)
    logger.info('Terminating test cycle...')
    model_delegate.terminate
  end

  def results(*args)
    extract_last, format, operation, sequences = args
    data = model_delegate.results(operation, sequences, format)
    tailed_data = extract_last && !data.empty? ? [data.last] : data
    [tailed_data, operation, format]
  end

  # Implements the purge commands as per options
  def purge(*args)
    option = args.first || :tests
    case option.to_sym
    when :tests
      model_delegate.execution_cycles.each(&:destroy)
      logger.info 'Purged all data for tests'
    when :clusters
      model_delegate.purge_clusters
      logger.info 'Purged all clusters'
    else
      model_delegate.destroy
      logger.info 'Purged all project data'
    end
  end

  def status(*args)
    format, = args
    running_agents = model_delegate.check_status if model_delegate.current_execution_cycle
    [running_agents, format]
  end
end
