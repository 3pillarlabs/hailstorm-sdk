require 'sidekiq'

class HailstormProcess
  include Sidekiq::Worker

  def perform(app_name, app_root_path, app_process, callback=nil, upload_directory_path=nil, project_id=nil, environment_data=nil)
  end
end