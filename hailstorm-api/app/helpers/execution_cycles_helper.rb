# Helper for ExecutionCycles API.
module ExecutionCyclesHelper

  # @param [Hailstorm::Model::ExecutionCycle] execution_cycle
  # @return [Hash]
  def execution_cycle_attributes(execution_cycle)
    # @type [Hash] attrs
    attrs = execution_cycle.attributes.symbolize_keys.except(:started_at, :stopped_at)
    attrs[:id] = execution_cycle.id
    attrs[:started_at] = execution_cycle.started_at.to_i * 1000
    attrs[:stopped_at] = execution_cycle.stopped_at.to_i * 1000 if execution_cycle.stopped_at
    if execution_cycle.status.to_sym == Hailstorm::Model::ExecutionCycle::States::STOPPED
      attrs[:response_time] = execution_cycle.avg_90_percentile
      attrs[:throughput] = execution_cycle.avg_tps
    end

    attrs
  end
end
