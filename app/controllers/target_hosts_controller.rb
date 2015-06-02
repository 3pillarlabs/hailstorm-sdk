class TargetHostsController < ApplicationController

  before_action :set_target_host, except: [:index, :new, :create]

  # GET /target_hosts
  # GET /target_hosts.json
  def index
    @target_hosts = @project.target_hosts
    if @target_hosts.empty?
      flash.now[:info] = 'No target hosts added for monitoring.'
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
  end

  # POST /target_hosts
  # POST /target_hosts.json
  def create
    @target_host = TargetHost.new(target_host_params)
    @target_host.project_id = @project.id
    respond_to do |format|
      if @target_host.save
        format.html { redirect_to project_target_hosts_path(@project), flash: {success: 'New host for monitoring added.'} }
      else
        format.html { render :new }
      end
    end
  end

  def edit
    # go conventions!
  end

  def update
    respond_to do |format|
      if @target_host.update(target_host_params)
        format.html { redirect_to project_target_hosts_path(@project), flash: {success: 'Host information updated.'} }
      else
        format.html { render :edit }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @target_host.destroy
        format.html { redirect_to project_target_hosts_path(@project, @target_host), flash: {success: 'Target host successfully removed from monitoring.'} }
      else
        format.html { redirect_to project_target_hosts_path(@project, @target_host), alert: "Could not remove target host: #{@target_host.errors.full_messages.join(';')}" }
      end
    end
  end

  private
    def delete_target_hosts(target_hosts_k)
      target_hosts_k.each do |host|
        host.destroy
      end
    end

    def formatted_target_host_data
      @target_host_data = TargetHost.where(:project_id=>params[:project_id]).group_by(&:role_name)
      unless @target_host_data.blank?
        @target_host_data = format_target_host(@target_host_data)
      end
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_target_host
      @target_host = TargetHost.where(project_id: @project.id).find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def target_host_params
      params.require(:target_host).permit(:host_name, :role_name, :executable_path, :user_name, :sampling_interval, :ssh_identity)
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
        unless key.blank?
          role[:name]= key
          role[:hosts] = []
          value.each do |h|
            unless h[:host_name].blank?
              role_host = {}
              role_host[:host_name] = h[:host_name]
              role_host[:monitor] = h
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
