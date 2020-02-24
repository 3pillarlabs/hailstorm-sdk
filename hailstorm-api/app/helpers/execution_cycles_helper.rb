module ExecutionCyclesHelper

  # @param [Hailstorm::Model::ExecutionCycle] execution_cycle
  def execution_cycle_attributes(execution_cycle)
    execution_cycle.attributes
                   .merge(
                     id: execution_cycle.id,
                     started_at: execution_cycle.started_at.to_i * 1000,
                     response_time: execution_cycle.avg_90_percentile,
                     throughput: execution_cycle.avg_tps
                   )
                   .merge(execution_cycle.stopped_at ? {stopped_at: execution_cycle.stopped_at.to_i * 1000} : {})
  end
end
