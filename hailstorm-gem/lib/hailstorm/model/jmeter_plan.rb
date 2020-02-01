require 'digest/sha1'
require 'nokogiri'

require 'hailstorm'
require 'hailstorm/model'
require 'hailstorm/model/load_agent'
require 'hailstorm/model/slave_agent'
require 'hailstorm/model/master_agent'
require 'hailstorm/support/workspace'

# Model class representing a JMeter test plan/script. Each model must be
# backed by an actual JMeter test plan in app/jmx.
# @author Sayantam Dey
class Hailstorm::Model::JmeterPlan < ActiveRecord::Base

  # Regular expression to match property names, always only matching the name
  # Examples of matches:
  #   ${__property(a)}
  #   ${__P(a)}
  #   ${__property(a, 1)}
  # In the first two cases above the regular expression will yield 'a' as the first (and only)
  # subgroup, while the third case will yied the default value as the second subgroup
  PROPERTY_NAME_REXP = Regexp.new('^\$\{__(?:P|property)\((.+?)(?:\)|\s*,\s*(.+?)\))\}$')

  JTL_FILE_EXTN = 'jtl'.freeze

  belongs_to :project

  has_many :load_agents, dependent: :nullify

  has_many :slave_agents

  has_many :master_agents

  validate :validate_plan, if: proc { |r| r.validate_plan? && r.active? }

  before_save :set_content_hash, if: proc { |r| r.active? }

  after_update :disable_load_agents, unless: proc { |r| r.active? }

  scope :active, -> { where(active: true) }

  attr_writer :validate_plan

  def validate_plan?
    @validate_plan
  end

  # Creates Hailstorm::Model::JmeterPlan instances corresponding to
  # config.test_plans. Each instance belongs to the project passed as argument.
  #
  # Before creating a JmeterPlan instance, the associated script is read
  # and validated for required properties; if one or more can not be
  # determined, a Hailstorm::Exception is raised.
  #
  # @param [Hailstorm::Model::Project] project
  # @param [Hailstorm::Support::Configuration] config
  # @return [Array] Hailstorm::Model::JmeterPlan instances
  def self.setup(project, config)
    logger.debug { "#{self}.#{__method__}" }
    jmeter_config = config.jmeter
    jmeter_plans = Hailstorm.fs.fetch_jmeter_plans(project.project_code)

    # load/verify test plans from app/jmx
    verified_plans = jmeter_config.test_plans.blank? ? jmeter_plans : load_selected_plans(jmeter_config, jmeter_plans)
    raise(Hailstorm::Exception, 'No test plans loaded.') if verified_plans.blank?

    # transfer files to workspace
    transfer_artifacts(project)

    # disable all plans and enable as per config.test_plans
    project.jmeter_plans.each { |jp| jp.update_attribute(:active, false) }

    to_jmeter_plans(jmeter_config, project, verified_plans)
  end

  def self.load_selected_plans(jmeter_config, jmeter_files)
    not_found = []
    test_plans = []
    jmeter_config.test_plans.each do |plan|
      path = jmeter_files.find { |jf| jf == plan }
      if path
        test_plans.push(plan)
      else
        not_found.push(plan)
      end
    end
    raise(Hailstorm::Exception, "Not all test plans found:\n#{not_found.join("\n")}") unless not_found.empty?

    test_plans
  end

  def self.transfer_artifacts(project)
    workspace = Hailstorm.workspace(project.project_code)
    workspace.make_app_layout(Hailstorm.fs.app_dir_tree(project.project_code))
    Hailstorm.fs.transfer_jmeter_artifacts(project.project_code, workspace.app_path)
  end

  def self.to_jmeter_plans(jmeter_config, project, test_plans)
    instances = test_plans.map do |plan|
      properties = jmeter_config.properties(test_plan: plan)
      jmeter_plan = self.where(test_plan_name: plan, project_id: project.id).first_or_initialize
      jmeter_plan.validate_plan = true
      jmeter_plan.active = true
      jmeter_plan.properties = properties.to_json
      jmeter_plan.save!
    end

    logger.debug('Validated all plans needed to execute')
    instances
  end

  # Useful for finding the process ID on remote agent.
  # @return [String] binary_name
  def self.binary_name
    'jmeter'.freeze
  end

  # Compares the calculated hash for source on disk and the
  # recorded hash of contents in the database.
  # @return [Boolean] true if hash matches, false otherwise
  def content_modified?
    self.content_hash.nil? || self.content_hash != calculate_content_hash
  end

  def properties_map
    @properties_map ||= self.properties ? JSON.parse(self.properties) : {}
  end

  # JMeter commands
  module CommandHelper
    # @param [String] slave_ip_address IP address (String) of the slave agent
    # @param [Hailstorm::Behavior::Clusterable] clusterable
    # @return [String] command to be executed on slave agent
    def slave_command(slave_ip_address, clusterable)
      logger.debug { "#{self.class}##{__method__}" }
      command_components = [
        "cd <%= @user_home %>/#{remote_working_dir};",
        'nohup',
        "<%= @jmeter_home %>/bin/#{self.class.binary_name}",
        '-Dserver_port=1099 -s',
        "-Djava.rmi.server.hostname=#{slave_ip_address}",
        "-j <%= @user_home %>/#{remote_log_dir}/#{remote_log_file(true)}"
      ]
      command_components.push(*property_options(clusterable))
      command_components.push('1>/dev/null 2>&1 </dev/null &')

      command_components.join(' ')
    end

    # @param [String] master_ip_address master IP address
    # @param [Array] slave_ip_addresses remote IP addresses (String)
    # @param [Hailstorm::Behavior::Clusterable] clusterable
    # @return [String] command to be executed on master agent
    def master_command(master_ip_address, slave_ip_addresses, clusterable)
      logger.debug { "#{self.class}##{__method__}" }

      self.update_column(:latest_threads_count, num_threads)
      command_components = [
        'nohup',
        "<%= @jmeter_home %>/bin/#{self.class.binary_name}",
        '-n',
        "-t <%= @user_home %>/#{remote_test_plan}",
        "-l <%= @user_home %>/#{remote_log_dir}/#{remote_log_file}"
      ]
      if slave_ip_addresses.blank?
        command_components.push(*property_options(clusterable))
      else
        command_components.push("-R #{slave_ip_addresses.join(',')}")
        command_components.push("-Djava.rmi.server.hostname=#{master_ip_address}")
        command_components.push('-X')
      end
      command_components.push('1>/dev/null 2>&1 </dev/null &')

      command_components.join(' ')
    end

    # The command to stop a running JMeter instance. The command will have ERB
    # placeholders for the master agent to interpolate.
    # @@return [String] the command
    def stop_command
      '<%= @jmeter_home %>/bin/shutdown.sh'
    end

    private

    # -J<name>=<value>
    # For threads_count properties, redistributes the load across agents
    def property_options(clusterable)
      if @property_options.nil?
        @property_options = []

        properties_map.each_pair do |name, value|
          if threadgroups_threads_count_properties.include?(name)
            value = value.to_f / clusterable.required_load_agent_count(self)
            value = if value < 1
                      1
                    else
                      value.round(0)
                    end
          end
          @property_options.push("-J\"#{name}=#{value}\"")
        end
      end

      @property_options
    end
  end

  # File system for project app (test plans)
  module AppFileSystem
    # Directory hierarchy is expressed as an Hash. The key is the directory name,
    # value is either nil or another Hash. When value is Hash, it represents a
    # subdirectory within the keyed parent.
    #
    # For example, if app has following directory tree, within "foobar" application:
    #   app
    #   |
    #    --- admin
    #   |
    #    --- main
    #        |
    #         --- accounts
    #        |
    #         --- shopping_cart
    #
    # The directory hierarchy would be:
    #   {
    #     "foobar" => {
    #       "log" => nil,
    #       "app" => {
    #         "admin" => nil,
    #         "main" => {
    #           "accounts" => nil
    #           "shopping_cart" => nil
    #         }
    #       }
    #     }
    #   }
    # @return [Hash] directory hierarchy to create on remote load agent
    def remote_directory_hierarchy
      logger.debug { "#{self.class}##{__method__}" }
      layout = {}
      layout[self.project.project_code] = {}
      layout[self.project.project_code][Hailstorm.log_dir] = nil
      layout[self.project.project_code].merge!(Hailstorm.fs.app_dir_tree(self.project.project_code))
      layout
    end

    # @return [Array] of local files needed for JMeter to operate
    def test_artifacts
      logger.debug { "#{self.class}##{__method__}" }
      test_artifacts = []
      # Do not upload files with ~, bk, bkp, backup in extension or starting with . (hidden)
      hidden_file_rexp = Regexp.new('^\.')
      backup_file_rexp = Regexp.new('(?:~|bk|bkp|backup|old|tmp)$')
      Hailstorm.workspace(self.project.project_code).app_entries.each do |entry|
        entry_name = File.basename(entry)
        test_artifacts.push(entry) unless hidden_file_rexp.match(entry_name) || backup_file_rexp.match(entry_name)
      end

      test_artifacts
    end

    def remote_log_dir
      @remote_log_dir ||= [self.project.project_code, Hailstorm.log_dir].join('/')
    end

    def remote_log_file(slave = false, execution_cycle = nil)
      if slave
        'server.log'
      else
        execution_cycle ||= self.project.current_execution_cycle
        "results-#{execution_cycle.id}-#{self.id}.#{JTL_FILE_EXTN}"
      end
    end

    private

    def remote_working_dir
      # FIXME: use File.dirname(test_plan_path)
      [self.project.project_code, Hailstorm.app_dir, File.dirname("#{self.test_plan_name}.jmx")].join('/')
    end

    def remote_test_plan
      # FIXME: use File.dirname(test_plan_path)
      [self.project.project_code, Hailstorm.app_dir, "#{self.test_plan_name}.jmx"].join('/')
    end
  end

  # Validation for JMeter test plan
  module JMeterDocumentValidator
    def validate_plan
      logger.debug { "#{self.class}##{__method__}" }
      unknown = []
      extracted_property_names.each do |name|
        unknown.push(name) if properties_map[name].blank?
      end
      unless unknown.empty?
        self.errors.add(:test_plan_name, "Unknown properties: #{unknown.join(',')} in #{self.test_plan_name}")
      end

      # check presence of simple data writer
      xpath = '//ResultCollector[@guiclass="SimpleDataWriter"][@enabled="true"]'
      jmeter_document do |doc|
        if doc.xpath(xpath).first.nil?
          self.errors.add(:test_plan_name, "Missing 'Simple Data Writer' JMeter listener in #{self.test_plan_name}")
        end
      end

      errors.blank?
    end
  end

  # JMeter document
  module JMeterDocument

    # @return [Boolean] true if the plan is configured to loop forever
    def loop_forever?
      if @loop_forever.nil?
        jmeter_document do |doc|
          e = doc.xpath('//boolProp[@name="LoopController.continue_forever"]')
          @loop_forever = e.children.empty? ? false : true.to_s == e.children.first.content
        end
      end
      @loop_forever
    end

    # Finds the value of TestPlan#testname attribute from the associated JMX
    # file. If it is not set to the generic value of "Test Plan", the value
    # is returned, else the file name (minus extension) is returned.
    # @return [String]
    def plan_name
      if @plan_name.nil?
        jmeter_document do |doc|
          test_plan = doc.xpath('//TestPlan').first
          @plan_name = test_plan['testname']
        end
        @plan_name = self.test_plan_name if @plan_name.blank? || @plan_name == 'Test Plan'
      end

      @plan_name
    end

    # Parses the associated test plan and returns the test plan comment
    # @return [String]
    def plan_description
      if @plan_description.nil?
        jmeter_document do |doc|
          plan_description_node = doc.xpath('//TestPlan/stringProp[@name="TestPlan.comments"]').first
          @plan_description = plan_description_node.nil? ? '' : plan_description_node.content
        end
      end
      @plan_description
    end

    # Parses the associated test plan and returns a definition of the thread groups
    # using name: comments for thread groups and name-comments for associated samplers.
    # If a comment is missing only name is present.
    #
    # Each "definition" is an OpenStruct instance with two keys: <b>thread_group</b> and <b>steps</b>,
    # where thread_group is a String and steps is an Array of String.
    #
    # Sample:
    #  [
    #    #{OpenStruct: @thread_group="threadgroup1#name: comment",
    #      @samplers=["sampler1#name: comment, sampler2#name: comment"]},
    #  ]
    # @return [Array] see sample for structure
    def scenario_definitions
      if @scenario_definitions.nil?
        @scenario_definitions = []
        tg_idx = 0
        jmeter_document do |doc|
          doc.xpath('//ThreadGroup').each do |tg|
            tg_idx += 1
            next unless tg['enabled'] == 'true'

            @scenario_definitions.push(create_defn(doc, tg, tg_idx))
          end
        end
      end

      @scenario_definitions
    end

    # Thread count in the JMeter thread group - if multiple thread groups are
    # present, the maximum is returned if serialize_threadgroups? is true, else
    # sum is taken.
    def num_threads
      logger.debug { "#{self.class}##{__method__}" }
      if @num_threads.nil?
        @num_threads = 0

        threadgroups_threads_count_properties.each do |property_name|
          value = properties_map[property_name]
          logger.debug("#{property_name} -> #{value}")

          if serialize_threadgroups?
            @num_threads = value if value > @num_threads
          else
            @num_threads += value
          end
        end
      end
      @num_threads
    end

    private

    # @return [Boolean] true if threadgroups are set to execute in serial order
    def serialize_threadgroups?
      logger.debug { "#{self.class}##{__method__}" }
      if @serialize_threadgroups.nil?

        @serialize_threadgroups = false
        jmeter_document do |doc|
          xpath = '/jmeterTestPlan//boolProp[@name="TestPlan.serialize_threadgroups"]'
          element = doc.xpath(xpath).first
          unless element.nil?
            if %w[true false].include?(element.content)
              @serialize_threadgroups = true.to_s == element.content
            else
              # load from property
              property_name = extract_property_name(element.content)
              @serialize_threadgroups = true.to_s == properties_map[property_name].to_s
            end
          end
        end
      end

      @serialize_threadgroups
    end

    # Array of property names for threads_count for all threadgroups
    def threadgroups_threads_count_properties
      logger.debug { "#{self.class}##{__method__}" }
      if @threadgroups_threads_count_properties.nil?
        @threadgroups_threads_count_properties = []
        xpath = '/jmeterTestPlan//ThreadGroup[@enabled="true"]/stringProp[@name="ThreadGroup.num_threads"]'
        jmeter_document do |doc|
          doc.xpath(xpath).each do |element|
            property_name = extract_property_name(element.content)
            @threadgroups_threads_count_properties.push(property_name)
          end
        end
      end
      @threadgroups_threads_count_properties
    end

    # extracts all property names from the file and returns Array.
    # XPATH implementation: Search for all nodes with content that contains "${__".
    # For each such node, check if content matches PropertyNameRexp, if it matches,
    # traverse up the node hierarchy to find a parent ThreadGroup. If parent ThreadGroup
    # is not found or parent Threadgroup is found with enabled attribute to true, add the
    # property name to the @extracted_property_names array.
    def extracted_property_names
      # Implemented XPATH lookup to fix Research-552
      return @extracted_property_names unless @extracted_property_names.nil?

      @extracted_property_names = []
      jmeter_document do |doc|
        doc.xpath('//*[contains(text(),"${__")]').each do |prop_element|
          property_name, default_value = parse_name_value(prop_element)
          next if property_name.nil?

          parent_thread_group = prop_element.ancestors('ThreadGroup').first

          if parent_thread_group.nil? || parent_thread_group['enabled'] == true.to_s
            @extracted_property_names.push(property_name)
            properties_map[property_name] = default_value unless properties_map.key?(property_name)
          end
        end
      end

      @extracted_property_names
    end

    def parse_name_value(prop_element)
      match_data = PROPERTY_NAME_REXP.match(prop_element.content)
      return nil if match_data.nil?

      property_name = match_data[1]
      default_value = match_data.size > 2 ? match_data[2] : nil
      [property_name, default_value]
    end

    def create_defn(doc, tgr, tg_idx)
      definition = OpenStruct.new
      tg_name = tgr['testname']
      tg_comment_node = doc.xpath("//ThreadGroup[@testname=\"#{tg_name}\"]/stringProp[@name=\"TestPlan.comments\"]")
                           .first
      definition.thread_group = tg_comment_node.nil? ? tg_name.to_s : "#{tg_name}: #{tg_comment_node.content}"

      # steps
      definition.samplers = []
      add_samples(definition, doc, tg_idx, tg_name)
      definition
    end

    def add_samples(definition, doc, tg_idx, tg_name)
      tg_xpath_expr_fmt = "//ThreadGroup[@testname=\"#{tg_name}\"]/../hashTree[#{tg_idx}]/hashTree"
      steps_xpath_expr = tg_xpath_expr_fmt + '//*[contains(@testclass,"Sampler") and @enabled="true"]'
      logger.debug(steps_xpath_expr)
      doc.xpath(steps_xpath_expr).each do |step| # (Sampler element)
        step_name = step['testname']
        # xpath to the current step
        current_step_xpath_expr = tg_xpath_expr_fmt +
                                  "//*[@testname=\"#{step_name}\" and contains(@testclass,\"Sampler\")]"
        step_comment_xpath_expr = "#{current_step_xpath_expr}/stringProp[@name=\"TestPlan.comments\"]"
        logger.debug(step_comment_xpath_expr)
        step_comment_node = doc.xpath(step_comment_xpath_expr).first
        definition.samplers.push(step_comment_node.nil? ? step_name.to_s : "#{step_name}: #{step_comment_node.content}")
      end
    end
  end

  # Adapter to low level Nokogiri API
  module NokogiriAdapter

    private

    # Parses the associated Jmeter file and yields a Nokogiri document or returns
    # the document if block is not provided.
    def jmeter_document
      logger.debug { "#{self.class}##{__method__}" }
      if @jmeter_document.nil?
        Hailstorm.workspace(self.project.project_code).open_app_file(self.test_plan_name) do |io|
          @jmeter_document = Nokogiri::XML.parse(io)
        end
      end

      yield(@jmeter_document) if block_given?
      @jmeter_document
    end
  end

  include CommandHelper
  include AppFileSystem
  include JMeterDocumentValidator
  include JMeterDocument
  include NokogiriAdapter

  ########################## PRIVATE METHODS ##################################
  private

  def calculate_content_hash
    digest = Digest::SHA2.new
    Hailstorm.workspace(self.project.project_code).open_app_file(self.test_plan_name) do |io|
      digest.update(io.read)
    end

    digest.hexdigest
  end

  def set_content_hash
    self.content_hash = calculate_content_hash
  end

  def disable_load_agents
    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.each { |a| a.update_column(:active, false) }
  end

  # extracts the property name from the property from the usage
  def extract_property_name(property_content)
    rexp_matcher = PROPERTY_NAME_REXP.match(property_content.strip)
    rexp_matcher.nil? ? nil : rexp_matcher[1]
  end
end
