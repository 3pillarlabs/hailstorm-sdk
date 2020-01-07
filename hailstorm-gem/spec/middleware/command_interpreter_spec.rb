require 'spec_helper'
require 'hailstorm/exceptions'
require 'hailstorm/middleware/command_interpreter'
require 'hailstorm/model/project'
require 'hailstorm/model/load_agent'

describe Hailstorm::Middleware::CommandInterpreter do

  before(:each) do
    @app = Hailstorm::Middleware::CommandInterpreter.new
  end

  context '#interpret_command' do
    context 'results' do
      it 'should interpret \'results\'' do
        expect(@app.interpret_command('results')).to eq [:results, false, nil, :show, nil]
      end
      %w[show exclude include report export import].each do |sc|
        it "should interpret 'results #{sc}'" do
          expect(@app.interpret_command("results #{sc}")).to eq [:results, false, nil, sc.to_sym, nil]
        end
      end
      it 'should interpret \'results import <path-spec>\'' do
        expect(@app.interpret_command('results import /tmp/b23d8/foo.jtl')).to eq [:results, false, nil, :import,
                                                                                   ['/tmp/b23d8/foo.jtl', nil]]
      end
      it 'should interpret \'results help\'' do
        expect(@app.interpret_command('results help')).to eq [:help, 'results']
      end
      it 'should interpret \'results show last\'' do
        expect(@app.interpret_command('results show last')).to eq [:results, true, nil, :show, nil]
      end
      it 'should interpret \'results last\'' do
        expect(@app.interpret_command('results last')).to eq [:results, true, nil, :show, nil]
      end
      %w[show exclude include report export].each do |sc|
        it "should interpret 'results #{sc} 1,2,3'" do
          expect(@app.interpret_command("results #{sc} 1,2,3")).to eq [:results, false, nil, sc.to_sym, [1, 2, 3]]
        end
        it "should interpret 'results #{sc} 4-8'" do
          expect(@app.interpret_command("results #{sc} 4-8")).to eq [:results, false, nil, sc.to_sym, [4, 5, 6, 7, 8]]
        end
        it "should interpret 'results #{sc} 7:8:9'" do
          expect(@app.interpret_command("results #{sc} 7:8:9")).to eq [:results, false, nil, sc.to_sym, [7, 8, 9]]
        end
      end
    end
    %w[quit exit].each do |command|
      it "should interpret '#{command}'" do
        expect(@app.interpret_command(command)).to eq [command.to_sym]
      end
    end
    context 'args as a Hash' do
      it 'should interpret command, arguments and format' do
        args = { args: %w[export 1-3], command: 'results', format: 'json' }
        expect(@app.interpret_command(args)).to eq [:results, false, :json, :export, [1, 2, 3]]
      end

      it 'should interpret command' do
        expect(@app.interpret_command({command: 'help'})).to eq([:help])
      end
    end
    context 'help' do
      it 'should interpret \'help\'' do
        expect(@app.interpret_command('help')).to eq [:help]
      end
      %w[setup start stop abort terminate results purge show status].each do |sc|
        it "should interpret 'help #{sc}'" do
          expect(@app.interpret_command("help #{sc}")).to eq [:help, sc]
        end
      end
    end
    context 'setup' do
      it 'should interpret \'setup\'' do
        expect(@app.interpret_command('setup')).to eq [:setup]
      end
      it 'should interpret \'setup force\'' do
        expect(@app.interpret_command('setup force')).to eq [:setup, 'force']
      end
      it 'should interpret \'setup help\'' do
        expect(@app.interpret_command('setup help')).to eq [:help, 'setup']
      end
    end
    context 'start' do
      it 'should interpret \'start\'' do
        expect(@app.interpret_command('start')).to eq [:start]
      end
      it 'should interpret \'start redeploy\'' do
        expect(@app.interpret_command('start redeploy')).to eq [:start, 'redeploy']
      end
      it 'should interpret \'start help\'' do
        expect(@app.interpret_command('start help')).to eq [:help, 'start']
      end
    end
    context 'stop' do
      it 'should interpret \'stop\'' do
        expect(@app.interpret_command('stop')).to eq [:stop]
      end
      ['suspend', 'wait', 'suspend wait', 'wait suspend'].each do |sc|
        it "should interpret 'stop #{sc}'" do
          expect(@app.interpret_command("stop #{sc}")).to eq [:stop, sc]
        end
      end
      it 'should interpret \'stop help\'' do
        expect(@app.interpret_command('stop help')).to eq [:help, 'stop']
      end
    end
    context 'abort' do
      it 'should interpret \'abort\'' do
        expect(@app.interpret_command('abort')).to eq [:abort]
      end
      it 'should interpret \'abort suspend\'' do
        expect(@app.interpret_command('abort suspend')).to eq [:abort, 'suspend']
      end
      it 'should interpret \'abort help\'' do
        expect(@app.interpret_command('abort help')).to eq [:help, 'abort']
      end
    end
    context 'purge' do
      it 'should interpret \'purge\'' do
        expect(@app.interpret_command('purge')).to eq [:purge]
      end
      %w[tests clusters all].each do |sc|
        it "should interpret 'purge #{sc}'" do
          expect(@app.interpret_command("purge #{sc}")).to eq [:purge, sc]
        end
      end
      it 'should interpret \'purge help\'' do
        expect(@app.interpret_command('purge help')).to eq [:help, 'purge']
      end
    end
    context 'show' do
      it 'should interpret \'show\'' do
        expect(@app.interpret_command('show')).to eq [:show]
      end
      %w[jmeter cluster monitor active].each do |sc|
        it "should interpret 'show #{sc}'" do
          expect(@app.interpret_command("show #{sc}")).to eq [:show, sc]
        end
        it "should interpret 'show #{sc} all'" do
          expect(@app.interpret_command("show #{sc} all")).to eq [:show, sc, 'all']
        end
      end
      it 'should interpret \'show help\'' do
        expect(@app.interpret_command('show help')).to eq [:help, 'show']
      end
    end
    context 'terminate' do
      it 'should interpret \'terminate\'' do
        expect(@app.interpret_command('terminate')).to eq [:terminate]
      end
      it 'should interpret \'terminate help\'' do
        expect(@app.interpret_command('terminate help')).to eq [:help, 'terminate']
      end
    end
    context 'status' do
      it 'should interpret \'status\'' do
        expect(@app.interpret_command('status')).to eq [:status]
      end
      it 'should interpret \'status help\'' do
        expect(@app.interpret_command('status help')).to eq [:help, 'status']
      end
    end
    context 'unknown command' do
      it 'should raise exception' do
        expect { @app.interpret_command('make coffee') }.to raise_error(Hailstorm::UnknownCommandException)
      end
    end
    context 'incorrect option for command' do
      it 'should raise exception' do
        expect {@app.interpret_command('start everything')}.to raise_error(Hailstorm::UnknownCommandException)
      end
    end
  end

  context '#translate_results_args' do
    context 'import' do
      it 'should understand file' do
        expect(@app.send(:translate_results_args, %w[import foo.jtl])).to be == [false, nil, :import, ['foo.jtl', nil]]
      end
      it 'should understand options' do
        translated_args = [false, nil, :import, [nil, {'jmeter' => '1', 'cluster' => '2'}]]
        expect(@app.send(:translate_results_args, ['import', 'jmeter=1 cluster=2'])).to be == translated_args
      end
      it 'should understand file and options' do
        translated_args = [false, nil, :import, ['/tmp/foo.jtl', {'jmeter' => '1', 'cluster' => '2'}]]
        expect(@app.send(:translate_results_args, ['import', '/tmp/foo.jtl jmeter=1 cluster=2'])).to be == translated_args
      end
      context '<options>' do
        it 'should accept `jmeter` option' do
          translated_args = [false, nil, :import, ['/tmp/foo.jtl', {'jmeter' => '1'}]]
          expect(@app.send(:translate_results_args, ['import', '/tmp/foo.jtl jmeter=1'])).to be == translated_args
        end
        it 'should accept `cluster` option' do
          translated_args = [false, nil, :import, ['/tmp/foo.jtl', {'cluster' => '1'}]]
          expect(@app.send(:translate_results_args, ['import', '/tmp/foo.jtl cluster=1'])).to be == translated_args
        end
        it 'should accept `exec` option' do
          translated_args = [false, nil, :import, ['/tmp/foo.jtl', {'exec' => '1'}]]
          expect(@app.send(:translate_results_args, ['import', '/tmp/foo.jtl exec=1'])).to be == translated_args
        end
        it 'should not accept an unknown option' do
          expect {
            @app.send(:translate_results_args, ['import', '/tmp/foo.jtl foo=1'])
          }.to raise_error(Hailstorm::Exception)
        end
      end
    end
    it 'should accept "last" as a valid sequence' do
      expect(@app.send(:translate_results_args, %w[show last])).to be == [true, nil, :show, nil]
    end
    it 'should accept a Range as a valid sequence' do
      expect(@app.send(:translate_results_args, %w[show 3-7])).to be == [false, nil, :show, [3, 4, 5, 6, 7]]
    end
    it 'should accept a comma or colon separated list of numbers as a valid sequence' do
      expect(@app.send(:translate_results_args, %w[show 3,4:5])).to be == [false, nil, :show, [3, 4, 5]]
    end
  end

  context '#parse_args' do
    context 'args is a Hash' do
      it 'should transform to :command_args and :format' do
        args = { args: %w[export 1-3], command: 'results', format: 'json' }
        expect(@app.send(:parse_args, args)).to eq ['results export 1-3'.to_sym, :json]
      end
    end
  end

  context '#parse_match_data' do
    it 'should partition the command and its arguments' do
      parsed_command_args = @app.send(:parse_match_data, ['results last', 'results', nil, ' last', ''])
      expect(parsed_command_args).to eq [:results, [nil, 'last']]
    end
    it 'should truncate empty or nil trailing arguments' do
      parsed_command_args = @app.send(:parse_match_data, ['results last', 'results', nil, '', ''])
      expect(parsed_command_args).to eq [:results, []]
    end
  end
end
