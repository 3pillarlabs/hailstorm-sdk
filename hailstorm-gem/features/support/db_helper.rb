require 'yaml'

# Database helper methods
module DbHelper
  def db_props
    YAML.load_file(File.expand_path('../../data/database.yml', __FILE__))[:cucumber.to_s]
  end
end
