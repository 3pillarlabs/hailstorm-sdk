class TargetHostsController < ApplicationController
  before_action :set_target_host, only: [:show]
  before_filter :set_project
  before_action :set_project_id, only: [:create]

  # GET /target_hosts
  # GET /target_hosts.json
  def index
    @target_hosts = TargetHost.where(:project_id=>params[:project_id]).group_by(&:role_name)
    if !@target_hosts.blank?
      @target_hosts = format_target_host(@target_hosts)
    end
  end

  # GET /target_hosts/1
  # GET /target_hosts/1.json
  def show
    if params[:format] == "pem"
      send_file @target_host.ssh_identity.path, :type => "application/x-x509-ca-cert", :disposition => 'attachment'
    else
      redirect_to project_target_hosts_path(@project)
    end
  end

  # GET /target_hosts/new
  def new
    @target_host = TargetHost.new
    @target_host_data = TargetHost.where(:project_id=>params[:project_id]).group_by(&:role_name)
    if !@target_host_data.blank?
      @target_host_data = format_target_host(@target_host_data)
    end
  end

  # POST /target_hosts
  # POST /target_hosts.json
  def create
    #delete all records related to project
    old_ts = TargetHost.where(:project_id => @project.id)
    puts old_ts.inspect
    process_status = 0
    target_host_parameter = {}
    target_host_parameter[:executable_path] = params[:target_host][:executable_path]
    target_host_parameter[:user_name] = params[:target_host][:user_name]
    target_host_parameter[:sampling_interval] = params[:target_host][:sampling_interval]
    target_host_parameter[:project_id] = params[:target_host][:project_id]
    target_host_parameter[:ssh_identity] = params[:target_host][:ssh_identity]

    respond_to do |format|
      params[:target_host][:host_name].each do |key,value|

        #if role not empty then
        if !params[:target_host][:role_name][key].blank?
          target_host_parameter[:role_name] = params[:target_host][:role_name][key]
          value.each do |host|
            target_host_parameter[:host_name] = ''

            #if host not empty then
            if !host.blank?
              target_host_parameter[:host_name] = host

              @target_host = TargetHost.new(target_host_parameter)
              if !@target_host.save
                format.html { render :new }
              else
                process_status = 1
              end
            end

          end

          #check if host empty then save data with role only
          if target_host_parameter[:host_name].blank?
            @target_host = TargetHost.new(target_host_parameter)
            if !@target_host.save
              format.html { render :new }
            else
              process_status = 1
            end
          end

        end

      end

      # if both role and host both are empty then
      if target_host_parameter[:role_name].blank? and target_host_parameter[:host_name].blank?
        @target_host = TargetHost.new(target_host_parameter)
        if @target_host.save
          delete_target_hosts(old_ts)
          format.html { redirect_to project_target_hosts_path(@project), notice: 'Target host was successfully created.' }
        else
          format.html { render :new }
        end
      elsif process_status==1
        delete_target_hosts(old_ts)
        format.html { redirect_to project_target_hosts_path(@project), notice: 'Target host was successfully created.' }
      end


    end
  end


  private
    def delete_target_hosts(target_hosts_k)
      #puts "in delete"
      #puts target_hosts.inspect
      target_hosts_k.each do |host|
        host.destroy
      end
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_target_host
      @target_host = TargetHost.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def target_host_params
      params.require(:target_host).permit(:project_id, :host_name, :role_name, :executable_path, :user_name, :sampling_interval, :ssh_identity)
    end

    def set_project_id
      params[:target_host][:project_id] = @project.id
    end

    def format_target_host(hosts)
      data = {}
      roles = []
      hosts.each do |key,value|
        role = {}
        if data.blank?
          data[:id] = value.first.id
          data[:project_id] = value.first.project_id
          data[:target_host_type] = value.first.target_host_type
          data[:executable_path] = value.first.executable_path
          data[:user_name] = value.first.user_name
          data[:sampling_interval] = value.first.sampling_interval
          data[:ssh_identity_file_name] = value.first.ssh_identity_file_name
        end
        if !key.blank?
          role[:name]= key
          role[:hosts] = []
          value.each do |h|
            if !h[:host_name].blank?
              role_host = {}
              role_host[:host_name] = h[:host_name]
              role[:hosts] << role_host
            end
          end
          roles << role
        end
      end
      data[:roles] = roles
      p data
      return data
    end

end
