require 'hailstorm/middleware'
require 'hailstorm/exceptions'

# Implements an 'interpreter' pattern to translate text commands to a command object.
class Hailstorm::Middleware::CommandInterpreter

  # Interpret the command (parse & execute)
  # @param [Array] args command arguments
  # @return [Array] command & args
  def interpret_command(*args)
    command, format = parse_args(args)
    match_data = find_matching_rule(command)
    method_name, method_args = parse_match_data(match_data)
    if method_args.length == 1 && method_args.first == 'help'
      [:help, method_name.to_s]
    else
      method_args.push(format) unless format.nil?
      [method_name].push(*method_args)
    end
  end

  private

  # Defines the grammar for the rules
  def grammar
    @grammar ||= %w[
      ^(help)(\s+setup|\s+start|\s+stop|\s+abort|\s+terminate|\s+results|\s+purge|\s+show|\s+status)?$
      ^(setup)(\s+force|\s+help)?$
      ^(start)(\s+redeploy|\s+help)?$
      ^(stop)(\s+suspend|\s+wait|\s+suspend\s+wait|\s+wait\s+suspend|\s+help)?$
      ^(abort)(\s+suspend|\s+help)?$
      ^(results)(\s+show|\s+exclude|\s+include|\s+report|\s+export|\s+import|\s+help)?(\s+[\d\-:,]+|\s+last)?(.*)$
      ^(purge)(\s+tests|\s+clusters|\s+all|\s+help)?$
      ^(show)(\s+jmeter|\s+cluster|\s+monitor|\s+help|\s+active)?(|\s+all)?$
      ^(terminate)(\s+help)?$
      ^(status)(\s+help)?$
      ^(quit|exit)?$
    ].collect { |p| Regexp.compile(p) }
  end

  def parse_args(args)
    format = nil
    if args.last.is_a? Hash
      options = args.last
      ca = (options[:args] || []).join(' ')
      command = "#{options[:command]} #{ca}".strip.to_sym
      format = options[:format]
    else
      command = args.last.to_sym
    end
    [command, format]
  end

  def find_matching_rule(command)
    match_data = nil
    grammar.each do |rule|
      match_data = rule.match(command.to_s)
      break if match_data
    end
    raise(Hailstorm::UnknownCommandException, "#{command} is unknown") unless match_data
    match_data
  end

  def parse_match_data(match_data)
    method_name = match_data[1].to_sym
    method_args = match_data.to_a
                            .slice(2, match_data.length - 1)
                            .select { |e| !e.blank? }
                            .collect(&:strip)
    [method_name, method_args]
  end
end
