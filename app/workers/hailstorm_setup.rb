require 'sidekiq'

class HailstormSetup
  include Sidekiq::Worker

  def perform(app_name, app_root_path, upload_directory_path, project_id, environment_data, callback)
  end
end