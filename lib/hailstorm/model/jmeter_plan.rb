# Model class representing a JMeter test plan/script. Each model must be
# backed by an actual JMeter test plan in app/jmx.
# @author Sayantam Dey

require 'digest/sha1'

require 'hailstorm'
require 'hailstorm/application'
require 'hailstorm/model'
require 'hailstorm/model/load_agent'
require 'hailstorm/model/slave_agent'
require 'hailstorm/model/master_agent'
require 'nokogiri'

class Hailstorm::Model::JmeterPlan < ActiveRecord::Base
  
  belongs_to :project
  
  has_many :load_agents, :dependent => :nullify
  
  has_many :slave_agents
  
  has_many :master_agents
  
  validate :validate_plan, :if => proc {|r| r.validate_plan? and r.active?}
  
  before_save :set_content_hash, :if => proc {|r| r.active?}
  
  after_update :disable_load_agents, :unless => proc {|r| r.active?}

  scope :active, ->{where(:active => true)}

  # Regular expression to match property names, always only matching the name
  # Examples of matches:
  #   ${__property(a)}
  #   ${_P(a)}
  #   ${__property(a, 1)}
  # In all cases above the regular expression will yield 'a' as the first (and only)
  # subgroup.
  PropertyNameRexp = Regexp.new('^\$\{__(?:P|property)\((.+?)(?:\)|\s*,\s*(?:.+?)\))\}$')
  
  JtlFileExtn = 'jtl'
  
  # Creates Hailstorm::Model::JmeterPlan instances corresponding to
  # config.test_plans. Each instance belongs to the project passed as argument.
  #
  # Before creating a JmeterPlan instance, the associated script is read
  # and validated for required properties; if one or more can not be
  # determined, a Hailstorm::Exception is raised.
  # 
  # @param [Hailstorm::Model::Project] project
  # @return [Array] of Hailstorm::Model::JmeterPlan instances
  def self.setup(project)
    
    logger.debug { "#{self}.#{__method__}" }
    instances = []
    jmeter_config = Hailstorm.application.config.jmeter
    
    test_plans = []
    # load/verify test plans from app/jmx
    if jmeter_config.test_plans.blank? # load
      rexp = Regexp.new('^'.concat(File.join(Hailstorm.root, Hailstorm.app_dir))
                            .concat("/"))
      Dir[File.join(Hailstorm.root, Hailstorm.app_dir, "**", "*.jmx")].each do |jmx|
        test_plans.push(jmx.gsub(rexp, '').gsub(/\.jmx$/, ''))
      end
      if test_plans.blank?
        raise(Hailstorm::Exception, "No test plans in #{Hailstorm.app_dir}.")
      end
      
    else # verify
      not_found = []
      jmeter_config.test_plans.each do |plan|
        jmx = File.join(Hailstorm.root, Hailstorm.app_dir,
                          plan.gsub(/\.jmx$/, '').concat('.jmx'))
        if File.exists?(jmx)
          test_plans.push(plan.gsub(/\.jmx$/, ''))
        else
          not_found.push(jmx)
        end
      end
      unless not_found.empty?
        raise(Hailstorm::Exception, "Not all test plans found:\n#{not_found.join("\n")}")
      end
    end
    
    # disable all plans and enable as per config.test_plans
    project.jmeter_plans.each do |jp| 
      jp.update_attribute(:active, false)
    end
    
    test_plans.each do |plan|
    
      properties = jmeter_config.properties(:test_plan => plan)
      
      jmeter_plan = self.where(:test_plan_name => plan,
                               :project_id => project.id)
                        .first_or_initialize()
      
      jmeter_plan.validate_plan = true                    
      jmeter_plan.active = true
      jmeter_plan.properties = properties.to_json
      jmeter_plan.save!
      instances.push(jmeter_plan)
    end
    logger.debug("Validated all plans needed to execute")

    return instances
  end

  # Compares the calculated hash for source on disk and the
  # recorded hash of contents in the database. 
  # @return [Boolean] true if hash matches, false otherwise
  def content_modified?
    self.content_hash.nil? || self.content_hash != calculate_content_hash()
  end
  
  # @return [String] path to the test plan
  def test_plan_file_path
    File.join(Hailstorm.root, Hailstorm.app_dir,
      "#{self.test_plan_name}.jmx")
  end
  
  # @param [String] slave_ip_address IP address (String) of the slave agent
  # @param [Hailstorm::Behavior::Clusterable] clusterable
  # @return [String] command to be executed on slave agent
  def slave_command(slave_ip_address, clusterable)
    
    logger.debug { "#{self.class}##{__method__}" }
    command_components = [
        "cd <%= @user_home %>/#{remote_working_dir};",
        "nohup",
        "<%= @jmeter_home %>/bin/#{self.class.binary_name}",
        "-Dserver_port=1099 -s",
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
      "nohup",
      "<%= @jmeter_home %>/bin/#{self.class.binary_name}",
      "-n",
      "-t <%= @user_home %>/#{remote_test_plan}",
      "-l <%= @user_home %>/#{remote_log_dir}/#{remote_log_file}"
    ]
    unless slave_ip_addresses.blank?
      command_components.push("-R #{slave_ip_addresses.join(',')}")
      command_components.push("-Djava.rmi.server.hostname=#{master_ip_address}")
      command_components.push('-X')
    else
      command_components.push(*property_options(clusterable))
    end
    command_components.push('1>/dev/null 2>&1 </dev/null &')

    command_components.join(' ')
  end

  # The command to stop a running JMeter instance. The command will have ERB
  # placeholders for the master agent to interpolate.
  # @@return [String] the command
  def stop_command()
    "<%= @jmeter_home %>/bin/shutdown.sh"
  end

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
  def remote_directory_hierarchy()
    
    logger.debug { "#{self.class}##{__method__}" }
    # pick app sub-directories
    app_entries = {}
    local_app_directories(File.join(Hailstorm.root, Hailstorm.app_dir), app_entries)
    if app_entries.empty?
      app_entries.merge!(Hailstorm.app_dir => nil)
    end

    return {
        Hailstorm.app_name => {
            Hailstorm.log_dir => nil
      }.merge(app_entries)
    }
  end
  
  # @return [Array] of local files needed for jmeter to operate
  def test_artifacts()

    logger.debug { "#{self.class}##{__method__}" }
    @test_artifacts = []
    # Do not upload files with ~, bk, bkp, backup in extension or starting with . (hidden)
    hidden_file_rexp = Regexp.new('^\.')
    backup_file_rexp = Regexp.new('(?:~|bk|bkp|backup|old|tmp)$')
    Dir[File.join(Hailstorm.root, Hailstorm.app_dir, '**', '*')].each do |entry|
      if File.file?(entry) # if its a regular file
        entry_name = File.basename(entry)
        unless hidden_file_rexp.match(entry_name) or backup_file_rexp.match(entry_name)
          @test_artifacts.push(entry)
        end
      end
    end
    
    logger.debug { @test_artifacts.inspect }
    @test_artifacts
  end
  
  attr_writer :validate_plan
  
  def validate_plan()
    
    logger.debug { "#{self.class}##{__method__}" }
    unknown = []
    extracted_property_names.each do |name|
      unknown.push(name) if properties_map[name].blank?
    end
    unless unknown.empty?
      self.errors.add(:test_plan_name, "Unknown properties: #{unknown.join(',')}. Please add these properties to config/environment.rb")
    end 

    # reverse check for unused properties
    unused_properties = []
    properties_map.keys.each do |name|
      unused_properties.push(name) unless extracted_property_names.include?(name)
    end
    unless unused_properties.empty?
      logger.warn(
          "Unused #{'property'.send(unused_properties.size == 1 ? :singularize : :pluralize)}: #{unused_properties.collect {|e| "'#{e}'"}.join(', ')}; detected in plan [#{File.join(Hailstorm.app_dir,"#{self.test_plan_name}.jmx")}]")
    end

    # check presence of simple data writer
    xpath = '//ResultCollector[@guiclass="SimpleDataWriter"][@enabled="true"]'
    jmeter_document() do |doc|
      if doc.xpath(xpath).first.nil?
        self.errors.add(:test_plan_name, "Missing 'Simple Data Writer' JMeter listener, please add to your test plan(s).")
      end
    end
    
    errors.blank?
  end
  
  def validate_plan?
    @validate_plan
  end
  
  # @return [Boolean] true if the plan is configured to loop forever
  def loop_forever?
    if @loop_forever.nil?
      jmeter_document() do |doc|
        e = doc.xpath('//boolProp[@name="LoopController.continue_forever"]')
        @loop_forever = eval(e.content.strip) rescue false
      end
    end
    @loop_forever
  end
  
  def remote_log_dir()
    @remote_log_dir ||= [Hailstorm.app_name, Hailstorm.log_dir].join('/')
  end
  
  def remote_log_file(slave = false, execution_cycle = nil)
    
    unless slave
      execution_cycle ||= self.project.current_execution_cycle 
      "results-#{execution_cycle.id}-#{self.id}.#{JtlFileExtn}"
    else
      "server.log"
    end  
  end

  # Finds the value of TestPlan#testname attribute from the associated JMX
  # file. If it is not set to the generic value of "Test Plan", the value
  # is returned, else the file name (minus extension) is returned.
  # @return [String]
  def plan_name()

    if @plan_name.nil?
      jmeter_document() do |doc|
        test_plan = doc.xpath('//TestPlan').first
        @plan_name = test_plan['testname']
      end
      if @plan_name.blank? or @plan_name == 'Test Plan'
        @plan_name = self.test_plan_name
      end
    end

    @plan_name
  end

  # Useful for finding the process ID on remote agent.
  # @return [String] binary_name
  def self.binary_name()
    'jmeter'
  end

  # Parses the associated test plan and returns the test plan comment
  # @return [String]
  def plan_description()

    if @plan_description.nil?
      jmeter_document() do |doc|
        plan_description_node = doc.xpath('//TestPlan/stringProp[@name="TestPlan.comments"]')
                                .first()
        @plan_description = plan_description_node.nil? ? '' : plan_description_node.content()
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
  #    #{OpenStruct: @thread_group="threadgroup1#name: comment", @samplers=["sampler1#name: comment, sampler2#name: comment"]},
  #  ]
  # @return [Array] see sample for structure
  def scenario_definitions()

    if @scenario_definitions.nil?
      @scenario_definitions = []
      jmeter_document() do |doc|
        doc.xpath('//ThreadGroup[@enabled="true"]').each do |tg|
          definition = OpenStruct.new()
          tg_name = tg['testname']
          tg_comment_node = doc.xpath("//ThreadGroup[@testname=\"#{tg_name}\"]/stringProp[@name=\"TestPlan.comments\"]")
                               .first()
          unless tg_comment_node.nil?
            definition.thread_group = "#{tg_name}: #{tg_comment_node.content}"
          else
            definition.thread_group = "#{tg_name}"
          end

          # steps
          definition.samplers = []

          tg_xpath_expr_fmt = '//ThreadGroup[@testname="%s"]/../hashTree/hashTree'
          steps_xpath_expr = sprintf(tg_xpath_expr_fmt, tg_name) +
              '//*[contains(@testclass,"Sampler") and @enabled="true"]'
          logger.debug(steps_xpath_expr)
          doc.xpath(steps_xpath_expr).each do |step| # (Sampler element)
            step_name = step['testname']
            # xpath to the current step
            current_step_xpath_expr = sprintf(tg_xpath_expr_fmt, tg_name) +
                "//*[@testname=\"#{step_name}\" and contains(@testclass,\"Sampler\")]"
            step_comment_xpath_expr = "#{current_step_xpath_expr}/stringProp[@name=\"TestPlan.comments\"]"
            logger.debug(step_comment_xpath_expr)
            step_comment_node = doc.xpath(step_comment_xpath_expr).first()
            unless step_comment_node.nil?
              definition.samplers << "#{step_name}: #{step_comment_node.content}"
            else
              definition.samplers << "#{step_name}"
            end
          end

          @scenario_definitions.push(definition)
        end
      end
    end

    return @scenario_definitions
  end

  def properties_map
    @properties_map ||= JSON.parse(self.properties)
  end

  # Thread count in the JMeter thread group - if multiple thread groups are
  # present, the maximum is returned if serialize_threadgroups? is true, else
  # sum is taken.
  def num_threads()

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

########################## PRIVATE METHODS ##################################
  private
  
  def calculate_content_hash()
    
    digest = Digest::SHA2.new
    File.open(test_plan_file_path(), "r") do |f|
      digest.update(f.gets())
    end
    
    return digest.hexdigest()
  end
  
  def set_content_hash()
    self.content_hash = calculate_content_hash()
  end

  def remote_working_dir()
    [
        Hailstorm.app_name,
        Hailstorm.app_dir,
        File.dirname("#{self.test_plan_name}.jmx")

    ].join('/')
  end

  def remote_test_plan()
    [Hailstorm.app_name, Hailstorm.app_dir,
      "#{self.test_plan_name}.jmx"].join('/')
  end
  
  # Parses the associated Jmeter file and yields a Nokogiri document or returns
  # the document if block is not provided.
  def jmeter_document(&block)
    
    logger.debug { "#{self.class}##{__method__}" }
    if @jmeter_document.nil?
      File.open(self.test_plan_file_path(), "r") do |file|
        @jmeter_document = Nokogiri::XML.parse(file)  
      end
    end

    if block_given?
      yield(@jmeter_document)
    else
      return @jmeter_document
    end
  end

  # Recursively picks directories within app
  # Example:
  #  {
  #    "app" => {
  #      "admin" => nil,
  #      "main" => {
  #        "accounts" => nil,
  #        "shopping_cart" => nil
  #      }
  #    }
  #  }
  # (see #remote_directory_hierarchy)
  def local_app_directories(start_dir, entries = {})
    
    logger.debug { "#{self.class}##{__method__}" }
    Dir[File.join(start_dir, '*')].each do |e|
      if File.directory?(e)
        parent = File.basename(start_dir).tap do |parent|
          entries[parent] = {} if entries[parent].nil?
          entries[parent][File.basename(e)] = nil
        end
        local_app_directories(e, entries[parent])
      end
    end
  end
  
  def disable_load_agents()
    
    logger.debug { "#{self.class}##{__method__}" }
    self.load_agents.each {|a| a.update_column(:active, false)}
  end
  
  # @return [Boolean] true if threadgroups are set to execute in serial order
  def serialize_threadgroups?
    
    logger.debug { "#{self.class}##{__method__}" }
    if @serialize_threadgroups.nil?
      
      @serialize_threadgroups = false
      jmeter_document() do |doc|
        xpath = '/jmeterTestPlan//boolProp[@name="TestPlan.serialize_threadgroups"]'
        element = doc.xpath(xpath).first()
        unless element.nil?
          if ['true', 'false'].include?(element.content)
            @serialize_threadgroups = eval(element.content) # true/false
          else
            # load from property
            property_name = extract_property_name(element.content)
            @serialize_threadgroups = eval(properties_map[property_name])
          end
          
        end 
      end
    end
    
    @serialize_threadgroups
  end
  
  # -J<name>=<value>
  # For threads_count properties, redistributes the load across agents
  def property_options(clusterable)
    
    if @property_options.nil?
      @property_options = []
      
      properties_map.each_pair do |name, value|
        if threadgroups_threads_count_properties.include?(name)
          value = value.to_f / clusterable.required_load_agent_count(self)
          if value < 1
            value = 1
          else
            value = value.round(0)
          end
        end
        @property_options.push("-J\"#{name}=#{value}\"")
      end
    end
    
    return @property_options
  end
  
  # Array of property names for threads_count for all threadgroups
  def threadgroups_threads_count_properties

    logger.debug { "#{self.class}##{__method__}" }
    if @threadgroups_threads_count_properties.nil?
      @threadgroups_threads_count_properties = []
      xpath = '/jmeterTestPlan//ThreadGroup[@enabled="true"]/stringProp[@name="ThreadGroup.num_threads"]'
      jmeter_document() do |doc|
        doc.xpath(xpath).each do |element|
          property_name = extract_property_name(element.content)
          @threadgroups_threads_count_properties.push(property_name)    
        end
      end
    end
    @threadgroups_threads_count_properties
  end

  # extracts the property name from the property from the usage  
  def extract_property_name(property_content)

    rexp_matcher = PropertyNameRexp.match(property_content.strip)
    rexp_matcher.nil? ? nil : rexp_matcher[1]
  end

  # extracts all property names from the file and returns Array.
  # XPATH implementation: Search for all nodes with content the constains "${__".
  # For each such node, check if content matches PropertyNameRexp, if it matches,
  # traverse up the node hierarchy to find a parent ThreadGroup. If parent ThreadGroup
  # is not found or parent Threadgroup is found with enabled attribute to true, add the
  # property name to the @extracted_property_names array.
  def extracted_property_names
    
    # Implemented XPATH lookup to fix Research-552
    if @extracted_property_names.nil?
      @extracted_property_names = []
      jmeter_document do |doc|
        doc.xpath('//*[contains(text(),"${__")]').each do |prop_element|
          match_data = PropertyNameRexp.match(prop_element.content)
          unless match_data.nil?
            property_name = match_data[1]
            parent_thread_group = prop_element.ancestors('ThreadGroup')
                                              .first()

            if parent_thread_group.nil? or (eval(parent_thread_group["enabled"]) rescue false)
              @extracted_property_names.push(property_name)
            end
          end
        end
      end
    end

    return @extracted_property_names
  end

end