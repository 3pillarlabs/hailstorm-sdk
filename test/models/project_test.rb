require 'test_helper'

describe Project do

  before do
    @project = Project.new
  end

  describe 'state' do
    it 'is empty at beginning' do
      @project.empty?.must_equal true
    end

    describe 'on adding a test plan' do
      it 'changes to :partial_configured' do
        @project.test_plan_upload
        @project.must_be :partial_configured?
      end
    end

    describe 'on adding multiple test plans' do
      it 'stays :partial_configured' do
        @project.test_plan_upload
        @project.test_plan_upload
        @project.must_be :partial_configured?
      end
    end

    describe 'starting at :setup_progress' do
      before do
        @project.aasm_state = :setup_progress
      end

      describe 'a :setup_done event' do
        it 'transitions to :ready start' do
          @project.setup_done
          @project.must_be :ready_start?
        end
      end

      describe 'a :setup_fail event' do
        it 'transitions back to :configured' do
          message = 'mocking a failure'
          @project.send(:setup_fail, nil, message)
          @project.must_be :configured?
          @project.state_reason.must_equal message
        end
      end
    end
  end

  describe 'new instance' do
    describe 'project_key' do

      before do
        @project.title = 'Totally Worthwhile Activity'
      end

      it 'is blank to start with' do
        @project.project_key.must_be :blank?
      end

      describe 'on validation' do

        before do
          @project.valid? # triggers validations
        end

        describe 'with blank project_key' do
          it 'is auto-generated' do
            @project.project_key.wont_be :blank?
          end
        end

        describe 'with previous project_key' do
          before do
            @project.project_key = 'tsa'
          end

          it 'is not modified' do
            @project.project_key.must_equal 'tsa'
          end
        end

      end
    end


  end

end