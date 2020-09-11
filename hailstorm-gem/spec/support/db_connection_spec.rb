# frozen_string_literal: true

require 'spec_helper'
require 'hailstorm/support/db_connection'

describe Hailstorm::Support::DbConnection do
  before(:each) do
    @connection = Hailstorm::Support::DbConnection.new({})
    allow(ActiveRecord::Base).to receive(:establish_connection)
  end

  context 'when database does not exist' do
    it 'should create a database' do
      allow(@connection).to receive(:test_connection!).and_raise(ActiveRecord::ActiveRecordError)
      expect(ActiveRecord::Base).to receive(:establish_connection)
      mock_connection = double('ActiveRecord::ConnectionAdapters')
      expect(mock_connection).to receive(:create_database)
      allow(ActiveRecord::Base).to receive(:connection).and_return(mock_connection)
      @connection.establish
    end
  end

  context 'when database already exists' do
    it 'should not create a database' do
      allow(@connection).to receive(:test_connection!)
      expect(@connection).to_not receive(:create_database)
      @connection.establish
    end
  end
end
