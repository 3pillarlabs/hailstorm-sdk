# Defaults for integration with Hailstorm


Rails.application.config.items_per_page = 10
Rails.application.config.uploads_directory = 'uploads'
Rails.application.config.uploads_path = ':rails_root/' + Rails.application.config.uploads_directory
Rails.application.config.data_center_default_user_name = 'ubuntu'
Rails.application.config.project_logs_file = 'hailstorm_status.log'
Rails.application.config.project_setup_path = File.join("#{Dir.home}", '/.hailstorm_projects')
