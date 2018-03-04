require 'spec_helper'
require 'hailstorm/exceptions'
require 'hailstorm/middleware/command_interpreter'
require 'hailstorm/model/project'
require 'hailstorm/model/load_agent'

describe Hailstorm::Middleware::CommandInterpreter do

  context '#interpret_command' do
    before(:each) do
      @app = Hailstorm::Middleware::CommandInterpreter.new
    end
    context 'results' do
      it 'should interpret \'results\'' do
        expect(@app.interpret_command('results')).to eq [:results]
      end
      %w[show exclude include report export import].each do |sc|
        it "should interpret 'results #{sc}'" do
          expect(@app.interpret_command("results #{sc}")).to eq [:results, sc]
        end
      end
      it 'should interpret \'results import <path-spec>\'' do
        expect(@app.interpret_command('results import /tmp/b23d8/foo.jtl')).to eq [:results, 'import',
                                                                                   '/tmp/b23d8/foo.jtl']
      end
      it 'should interpret \'results help\'' do
        expect(@app.interpret_command('results help')).to eq [:help, 'results']
      end
      it 'should interpret \'results show last\'' do
        expect(@app.interpret_command('results show last')).to eq [:results, 'show', 'last']
      end
      it 'should interpret \'results last\'' do
        expect(@app.interpret_command('results last')).to eq [:results, 'last']
      end
      %w[1,2,3 4-8 7:8:9].each do |seq|
        %w[show exclude include report export].each do |sc|
          it "should interpret 'results #{sc} #{seq}'" do
            expect(@app.interpret_command("results #{sc} #{seq}")).to eq [:results, sc, seq]
          end
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
        args = {args: %w[export 1-3], command: 'results', format: 'json'}
        expect(@app.interpret_command(args)).to eq [:results, 'export', '1-3', 'json']
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
end
