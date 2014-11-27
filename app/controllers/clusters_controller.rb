class ClustersController < ApplicationController
  before_action :set_cluster, :except => [:index, :new, :create]
  before_filter :set_project
  before_action :set_project_id, only: [:create, :update]
  before_action :convert_machines_json_to_array, :only => [:edit]

  # GET /clusters
  # GET /clusters.json
  def index
    @items_per_page = Rails.configuration.items_per_page
    @current_page = params[:page].blank? ? 1 : params[:page]
    # @clusters = Cluster.where(:project_id=>params[:project_id]).pagination(@current_page, @items_per_page)
    cluster_obj = Cluster.new
    cluster_type = params[:type].blank? ? "amazon_cloud" : params[:type]
    @clusters = cluster_obj.getClustersOfType(cluster_type, params[:project_id]).pagination(@current_page, @items_per_page)
  end

  # GET /clusters/1
  # GET /clusters/1.json
  def show
    if params[:format] == "pem"
      send_file @cluster.ssh_identity.path, :type => "application/x-x509-ca-cert", :disposition => 'attachment'
    end
  end

  # GET /clusters/new
  def new
    @cluster = Cluster.new
  end

  # GET /clusters/1/edit
  def edit
  end

  # POST /clusters
  # POST /clusters.json
  def create
    @cluster = Cluster.new(cluster_params)

    respond_to do |format|
      if @cluster.save
        #format.html { redirect_to @cluster, notice: 'Cluster was successfully created.' }
        format.html { redirect_to project_clusters_path(@project,:type => @cluster.name), notice: 'Cluster was successfully created.' }
        format.json { render :show, status: :created, location: @cluster }
      else
        convert_machines_json_to_array
        format.html { render :new }
        format.json { render json: @cluster.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /clusters/1
  # PATCH/PUT /clusters/1.json
  def update
    respond_to do |format|
      if @cluster.update(cluster_params)
        format.html { redirect_to project_clusters_path(@project,:type => @cluster.name), notice: 'Cluster was successfully updated.' }
        format.json { render :show, status: :ok, location: @cluster }
      else
        convert_machines_json_to_array
        format.html { render :edit }
        format.json { render json: @cluster.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /clusters/1
  # DELETE /clusters/1.json
  def destroy
    @cluster.destroy
    respond_to do |format|
      #format.html { redirect_to clusters_url, notice: 'Cluster was successfully destroyed.' }
      format.html { redirect_to project_clusters_path(@project), notice: 'Cluster was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cluster
      @cluster = Cluster.find(params[:id])
    end

    def set_project_id
      params[:cluster][:project_id] = @project.id
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def cluster_params
      if(params[:cluster][:name] == "amazon_cloud")
        params.require(:cluster).permit(:project_id, :name, :access_key, :secret_key, :ssh_identity, :region, :instance_type)
      elsif(params[:cluster][:name] == "data_center")
        params[:cluster][:machines] = params[:cluster][:machines].reject{ |e| e.blank? }.to_json
        params.require(:cluster).permit(:project_id, :name, :user_name, :machines, :ssh_identity)
      end
    end

    def convert_machines_json_to_array
      if ! @cluster.machines.blank?
        @cluster.machines = JSON.parse(@cluster.machines)
      end
    end
end
