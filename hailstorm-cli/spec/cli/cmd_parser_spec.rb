require 'spec_helper'
require 'hailstorm/cli/cmd_parser'

describe Hailstorm::Cli::CmdParser do

  before(:each) do
    @parser = Hailstorm::Cli::CmdParser.new
  end

  context '#parse!' do

    context '--cmd foo' do

      context 'options' do
        it 'should have :command => foo' do
          @parser.parse!(%w[hailstorm --cmd foo]) do |options|
            expect(options[:command]).to be == 'foo'
          end
        end
      end

      context '--args a,b,c' do

        context 'options' do
          it 'should have :args => %w[a b c]' do
            @parser.parse!(%w[hailstorm --cmd foo --args a,b,c]) do |options|
              expect(options[:command]).to be == 'foo'
              expect(options[:args]).to be == %w[a b c]
            end
          end
        end

        context '--format json' do
          context 'options' do
            it 'should have :format => json' do
              @parser.parse!(%w[hailstorm --cmd foo --args a,b,c --format json]) do |options|
                expect(options[:command]).to be == 'foo'
                expect(options[:args]).to be == %w[a b c]
                expect(options[:format]).to be == 'json'
              end
            end
          end
        end
      end
    end

    context 'parse error' do
      context 'without @parse_error_handler' do
        it 'should raise error' do
          expect { @parser.parse!(%w[hailstorm --foo setup]) }.to raise_error
        end
      end
      context 'with @parse_error_handler' do
        it 'should invoke the handler' do
          error_yields = []
          @parser.on_parse_error { |error, opt_parser| error_yields.push(error, opt_parser) }
          @parser.parse!(%w[hailstorm --foo setup])
          expect(error_yields.size).to eq(2)
        end
      end
    end

    context '--help' do
      context 'with @help_handler' do
        it 'should invoke the handler' do
          help_yields = []
          @parser.on_help { |opt_parser| help_yields.push(opt_parser) }
          @parser.parse!(%w[hailstorm --help])
          expect(help_yields.size).to eq(1)
        end
      end
    end

    context '#with_default_handlers' do

      context '--help' do
        it 'should print to STDOUT' do
          stdout_io = StringIO.new
          @parser.with_default_handlers(false, nil, stdout_io).parse!(%w[hailstorm --help])
          expect(stdout_io.length).to be > 0
        end
      end

      context 'invalid option' do
        it 'should print to STDERR' do
          stderr_io = StringIO.new
          @parser.with_default_handlers(false, stderr_io).parse!(%w[hailstorm -x])
          expect(stderr_io.length).to be > 0
        end
      end
    end
  end
end
