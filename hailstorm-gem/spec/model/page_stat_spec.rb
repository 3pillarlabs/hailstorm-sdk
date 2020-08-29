require 'spec_helper'
require 'hailstorm/model/page_stat'

describe Hailstorm::Model::PageStat do

  context '.collect_sample' do
    before(:each) do
      @page_stat = Hailstorm::Model::PageStat.new(client_stat: Hailstorm::Model::ClientStat.new,
                                                  page_label: 'a')
      allow(@page_stat).to receive(:samples_breakup)
    end
    it 'should increment errors_count and samples_count on sample failure' do
      expect(@page_stat).to receive(:increment).with(:samples_count)
      expect(@page_stat.errors_count).to be == 0
      sample = { t: '123', ts: Time.now.to_i.to_s, by: '12', s: 'false' }.stringify_keys
      @page_stat.collect_sample(sample)
      expect(@page_stat.errors_count).to be == 1
    end
    it 'should increment only samples_count on sample success' do
      expect(@page_stat).to receive(:increment).with(:samples_count)
      expect(@page_stat.errors_count).to be == 0
      sample = { t: '123', ts: Time.now.to_i.to_s, by: '12', s: 'true' }.stringify_keys
      @page_stat.collect_sample(sample)
      expect(@page_stat.errors_count).to be == 0
    end
  end

  context '#stat_item' do
    it 'should return scalar attributes' do
      model_attributes = {
        page_label: 'a',
        samples_count: 1000,
        average_response_time: 12,
        median_response_time: 15,
        ninety_percentile_response_time: 14,
        minimum_response_time: 10,
        maximum_response_time: 20,
        percentage_errors: 1.23,
        response_throughput: 123.4,
        size_throughput: 12.3,
        standard_deviation: 1
      }
      page_stat = Hailstorm::Model::PageStat.new(model_attributes.merge(client_stat_id: 1, samples_breakup_json: '{}'))
      page_stat.id = 9
      stat_item = page_stat.stat_item
      %i[id, client_stat_id, samples_breakup_json].each { |attr| expect(stat_item.send(attr)).to be_nil }
      model_attributes.each { |key, value| expect(stat_item.send(key)).to be == value }
    end
  end
end
