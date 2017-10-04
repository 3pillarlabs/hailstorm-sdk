require 'spec_helper'
require 'hailstorm/application'
require 'hailstorm/model/project'

describe Hailstorm::Application do

  context '#interpret_command' do
    it 'should find valid "results import"' do
      app = Hailstorm::Application.new
      app.stub(:current_project) { mock(Hailstorm::Model::Project).as_null_object }
      expect(app.interpret_command('results import')).to eql(:results)
    end
    it 'should find valid "results import <pathspec>"' do
      app = Hailstorm::Application.new
      app.stub(:current_project) { mock(Hailstorm::Model::Project).as_null_object }
      expect(app.interpret_command('results import /tmp/b23d8/foo.jtl')).to eql(:results)
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
      it 'should understand file' do
        @app.current_project.should_receive(:results).with(:import, ['foo.jtl', nil])
        @app.send(:results, 'import', 'foo.jtl')
      end
      it 'should understand options' do
        @app.current_project.should_receive(:results).with(:import, [nil, {'foo' => '1', 'bar' => '2', 'baz' => '3'}])
        @app.send(:results, 'import', 'foo=1 bar=2 baz=3')
      end
      it 'should understand file and options' do
        @app.current_project.should_receive(:results).with(:import, ['/tmp/foo.jtl', {'foo' => '1', 'bar' => '2', 'baz' => '3'}])
        @app.send(:results, 'import', '/tmp/foo.jtl foo=1 bar=2 baz=3')
      end
      it 'should understand execution cycle, file and options'
    end
  end

end
