require 'spec_helper'
require 'helpers/api_helper'

describe ApiHelper do
  include ApiHelper

  context '#deep_camelize_keys' do
    it 'should camelize all keys of a hash' do
      input = {
        id: 22,
        title: "Acme Priming",
        code: "acme_priming",
        running: true,
        current_execution_cycle: {
          id: 122,
          project_id: 22,
          status: "started",
          stopped_at: nil,
          threads_count: 50,
          started_at: 1581251597000
        },
        last_execution_cycle: {
          id: 121,
          project_id:22,
          status: "stopped",
          threads_count: 30,
          response_time:678.45,
          throughput: 14.56,
          started_at:1581248897000,
          stopped_at:1581250697000
        },
        auto_stop:true,
        incomplete:true
      }

      output = deep_camelize_keys(input)
      expect(output.keys.sort).to eq(%W[id title code running currentExecutionCycle lastExecutionCycle autoStop incomplete].sort)
      expect(output['currentExecutionCycle'].keys.sort).to eq(%W[id projectId status stoppedAt threadsCount startedAt].sort)
      expect(output['lastExecutionCycle'].keys).to include('startedAt')
      expect(output['lastExecutionCycle'].keys).to include('stoppedAt')
    end
  end
end
