class LoadTestsController < ApplicationController

  before_action :set_load_test, except: [:index]

  def index
    load_test_list(params[:active].nil? || params[:active] == 'true')
  end

  def update
    update_params = params.require(:load_test).permit(:active)
    @load_test.update_attribute(:active, update_params[:active])
    load_test_list(!@load_test.active)
  end

  def destroy
    respond_to do |format|
      begin
        @load_test.update_attribute(:active, false)
        format.html { render partial: 'load_tests/list', object: @project.load_tests.reverse_chronological_list }
      rescue
        format.any { head :bad_request }
      end
    end
  end

  private

  def set_load_test
    @load_test = LoadTest.unscoped.where(project_id: @project.id).find(params[:id])
  end

  def load_test_list(active)
    q = active ? @project.load_tests : LoadTest.unscoped.where(active: false, project_id: @project.id)
    respond_to do |format|
      format.html { render partial: 'load_tests/list', object: q.reverse_chronological_list }
    end
  end

end
