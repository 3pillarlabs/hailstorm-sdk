require 'spec_helper'
require 'hailstorm/model/project'

describe Hailstorm::Model::Project do

  context 'by default' do
    it 'should have JMeter version as 3.2' do
      @project = Hailstorm::Model::Project.new
      @project.send(:set_defaults)
      expect(@project.jmeter_version).to eq 3.2
    end
  end
end
