require 'spec_helper'
require 'hailstorm/cli/cmd_history'

describe Hailstorm::Cli::CmdHistory do

  context '#saved_history_path' do
    it 'should have a default value' do
      cmd_history = Hailstorm::Cli::CmdHistory.new([])
      expect(cmd_history.saved_history_path).to_not be_blank
    end
  end

  context '#save_history' do
    before(:each) do
      history_file_path = File.join(Hailstorm.root, 'spec_hailstorm_history')
      FileUtils.safe_unlink(history_file_path)

      @cmd_history = Hailstorm::Cli::CmdHistory.new([], max_history_size: 10)
      @cmd_history.stub!(:saved_history_path).and_return(history_file_path)
    end

    it 'should add a new command' do
      expect(@cmd_history.save_history('start').last).to be == 'start'
    end

    it 'should not add successive duplicate commands' do
      @cmd_history.save_history('start')
      expect(@cmd_history.save_history('start').size).to be == 1
    end

    it 'should not exceed maximum history file size' do
      penultimate_count = @cmd_history.max_history_size - 1
      penultimate_count.times do |index|
        @cmd_history.save_history("command #{index + 1}")
      end

      expect(@cmd_history.save_history("command #{penultimate_count + 1}").size).to be == penultimate_count + 1
      expect(@cmd_history.save_history("command #{penultimate_count + 2}").size).to be == penultimate_count + 1
    end
  end
end
