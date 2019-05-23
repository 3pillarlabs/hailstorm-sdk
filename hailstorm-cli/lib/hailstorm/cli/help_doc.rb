require 'hailstorm/cli'
require 'yaml'

# Help doc string for CLI
class Hailstorm::Cli::HelpDoc

  attr_reader :help_docs_path

  def initialize(new_help_docs_path)
    @help_docs_path = new_help_docs_path
  end

  %i[help setup start stop abort terminate results show purge status]
    .map { |cmd| "#{cmd}_options" }.each do |method_name|

    define_method(method_name) do
      value = instance_variable_get("@#{method_name}")
      unless value
        value = help_docs[method_name.to_s].strip_heredoc
        instance_variable_set("@#{method_name}", value)
      end
      value
    end
  end

  private

  def help_docs
    @help_docs ||= YAML.load_file(self.help_docs_path)
  end
end
