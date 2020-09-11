# frozen_string_literal: true

require 'hailstorm/middleware'
require 'hailstorm/exceptions'
require 'hailstorm/behavior/loggable'

# Implements an 'interpreter' pattern to translate text commands to a command object.
class Hailstorm::Middleware::CommandInterpreter

  include Hailstorm::Behavior::Loggable

  # Interpret the command (parse & execute)
  # @param [Array] args command arguments
  # @return [Array] command & args
  def interpret_command(*args)
    command, format = parse_args(*args)
    match_data = find_matching_rule(command)
    method_name, method_args = parse_match_data(match_data)
    if method_args.length == 1 && method_args.first == 'help'
      [:help, method_name.to_s]
    else
      method_args.push(format) unless format.nil?
      translation = "translate_#{method_name}_args".to_sym
      if respond_to?(translation)
        [method_name].push(*send(translation, method_args))
      else
        [method_name].push(*method_args)
      end
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
      ^(results)(\s+show|\s+exclude|\s+include|\s+report|\s+export|\s+import|\s+help)?(\s+[\d\-:,]+|\s+last|\s+.*)?$
      ^(purge)(\s+tests|\s+clusters|\s+all|\s+help)?$
      ^(show)(\s+jmeter|\s+cluster|\s+monitor|\s+help|\s+active)?(|\s+all)?$
      ^(terminate)(\s+help)?$
      ^(status)(\s+help)?$
      ^(quit|exit)?$
    ].collect { |p| Regexp.compile(p) }
  end

  def parse_args(*args)
    format = nil
    if args.last.is_a? Hash
      options = args.last
      ca = (options[:args] || []).join(' ')
      command = "#{options[:command]} #{ca}".strip.to_sym
      format = options[:format].to_s.to_sym if options[:format]
    else
      command = args.last.to_sym
    end
    logger.debug { [command, format] }
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
    method_args = truncate_trailing_empty_values(match_data)
    [method_name, method_args]
  end

  def truncate_trailing_empty_values(match_data)
    match_data.to_a
              .slice(2, match_data.length - 1)
              .reverse
              .reduce([]) { |s, e| !s.empty? || !e.blank? ? s << e : s }
              .reverse
              .collect { |e| e ? e.strip : e }
  end

  # Mixin methods for results translation
  module ResultsTranslationMixin

    def translate_results_args(args)
      format, operation, sequences = expand_args(args)
      extract_last, sequences = interpret_sequences(args, sequences)
      [extract_last, format, operation, sequences]
    end

    def expand_args(args)
      case args.length
      when 3
        operation, sequences, format = args
      when 2
        operation, sequences = args
      else
        operation, = args
      end
      operation = (operation || 'show').to_sym
      [format, operation, sequences]
    end

    def interpret_sequences(args, sequences)
      extract_last = false
      if sequences
        case sequences
        when /^last$/
          extract_last = true
          sequences = nil

        when /^(\d+)-(\d+)$/ # range
          sequences = (Regexp.last_match(1)..Regexp.last_match(2)).to_a.collect(&:to_i)

        when /^[\d,:]+$/
          sequences = sequences.split(/\s*[,:]\s*/).collect(&:to_i)

        else
          sequences = parse_results_import_arguments(sequences)
          logger.debug { "results(#{args}) -> #{sequences}" }
        end
      end
      [extract_last, sequences]
    end

    def parse_results_import_arguments(sequences)
      glob, opts = seq_to_glob_opts(sequences)
      if glob.is_a?(Hash)
        opts = glob
        glob = nil
      end

      opts&.each_key do |opt_key|
        unless %i[jmeter exec cluster].include?(opt_key.to_sym)
          raise(Hailstorm::UnknownCommandOptionException, "Unknown results import option: #{opt_key}")
        end
      end
      [glob, opts]
    end

    # Converts 'foo.jtl jmeter=1 cluster=2' to ['foo.jtl', {'jmeter' => '1'}, {'cluster' => '2'}]
    def seq_to_glob_opts(sequences)
      glob, opts = sequences.split(/\s+/).each_with_object([]) do |e, a|
        if e =~ /=/
          a.push({}) if a.last.nil? || a.last.is_a?(String)
          k, v = e.split(/=/)
          a.last.merge!(k => v)
        else
          a.unshift(e)
        end
      end
      [glob, opts]
    end
  end

  include ResultsTranslationMixin
end
