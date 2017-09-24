require 'spec_helper'
require 'hailstorm/application'
require 'hailstorm/model/project'

describe Hailstorm::Application do

  context '#interpret_command' do
    it 'should find valid "results import"' do
      app = Hailstorm::Application.new
      expect(app.interpret_command('results import')).to eql(:results)
    end
    it 'should find valid "results import <pathspec>"' do
      app = Hailstorm::Application.new
      expect(app.interpret_command('results import /tmp/b23d8/*.jtl')).to eql(:results)
    end
  end

  context '#results' do
    context 'import' do
      before(:each) do
        @app = Hailstorm::Application.new
        class << @app
          include RSpec::Mocks::ExampleMethods
          def current_project
            if @current_project.nil?
              @current_project = mock(Hailstorm::Model::Project)
              @current_project.stub!(:results)
            end
            @current_project
          end
        end
      end
      it 'should understand glob' do
        @app.current_project.should_receive(:results).with(:import, ['*.jtl', nil])
        @app.send(:results, 'import', '*.jtl')
      end
      it 'should understand options' do
        @app.current_project.should_receive(:results).with(:import, [nil, {'foo' => '1', 'bar' => '2', 'baz' => '3'}])
        @app.send(:results, 'import', 'foo=1 bar=2 baz=3')
      end
      it 'should understand glob and options' do
        @app.current_project.should_receive(:results).with(:import, ['/tmp/*.jtl', {'foo' => '1', 'bar' => '2', 'baz' => '3'}])
        @app.send(:results, 'import', '/tmp/*.jtl foo=1 bar=2 baz=3')
      end
    end
  end

end
