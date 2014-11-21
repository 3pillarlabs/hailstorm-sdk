class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  private

  # Use callbacks to share common setup or constraints between actions for project.
  def set_project
    @project = Project.find(params.has_key?(:project_id) ? params[:project_id] : params[:id])
  end

end
