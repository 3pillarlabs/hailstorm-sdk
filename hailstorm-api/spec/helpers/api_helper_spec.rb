# frozen_string_literal: true

require 'spec_helper'
require 'helpers/api_helper'

describe ApiHelper do
  include ApiHelper

  context '#deep_camelize_keys' do
    it 'should camelize all keys of a hash' do
      input = {
        id: 22,
        title: 'Acme Priming',
        code: 'acme_priming',
        running: true,
        current_execution_cycle: {
          id: 122,
          project_id: 22,
          status: 'started',
          stopped_at: nil,
          threads_count: 50,
          started_at: 1_581_251_597_000
        },
        last_execution_cycle: {
          id: 121,
          project_id: 22,
          status: 'stopped',
          threads_count: 30,
          response_time: 678.45,
          throughput: 14.56,
          started_at: 1_581_248_897_000,
          stopped_at: 1_581_250_697_000
        },
        auto_stop: true,
        incomplete: true
      }

      output = deep_camelize_keys(input)
      expected_output_keys = %w[id title code running currentExecutionCycle lastExecutionCycle autoStop incomplete]
      expect(output.keys.sort).to eq(expected_output_keys.sort)
      sub_hash_keys = %w[id projectId status stoppedAt threadsCount startedAt]
      expect(output['currentExecutionCycle'].keys.sort).to eq(sub_hash_keys.sort)
      expect(output['lastExecutionCycle'].keys).to include('startedAt')
      expect(output['lastExecutionCycle'].keys).to include('stoppedAt')
    end
  end
end
