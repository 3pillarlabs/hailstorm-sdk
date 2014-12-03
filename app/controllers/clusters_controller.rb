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
    # cluster_obj = Cluster.new
    cluster_type = params[:type].blank? ? "DataCenter" : params[:type]
    # @clusters = cluster_obj.getClustersOfType(cluster_type, params[:project_id]).pagination(@current_page, @items_per_page)
    if(cluster_type == "AmazonCloud")
      @clusters = @project.amazon_clouds.pagination(@current_page, @items_per_page)
    elsif(cluster_type == "DataCenter")
      @clusters = @project.data_centers.pagination(@current_page, @items_per_page)
    end

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
    if(params[:cluster][:type] == "AmazonCloud")
      @cluster = AmazonCloud.new(cluster_params)
    elsif(params[:cluster][:type] == "DataCenter")
      @cluster = DataCenter.new(cluster_params)
    end

    respond_to do |format|
      if @cluster.save
        #format.html { redirect_to @cluster, notice: 'Cluster was successfully created.' }
        if(params[:cluster][:type] == "AmazonCloud")
          format.html { redirect_to project_amazon_clouds_path(@project), notice: 'Amazon cloud cluster was successfully created.' }
        elsif(params[:cluster][:type] == "DataCenter")
          format.html { redirect_to project_data_centers_path(@project), notice: 'Data center cluster was successfully created.' }
        end

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
        if(params[:type] == "AmazonCloud")
          format.html { redirect_to project_amazon_clouds_path(@project), notice: 'Amazon cloud cluster was successfully updated.' }
        elsif(params[:type] == "DataCenter")
          format.html { redirect_to project_data_centers_path(@project), notice: 'Data center cluster was successfully updated.' }
        end
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
      if(!params[:data_center].blank?)
        params[:data_center][:project_id] = @project.id
      elsif(!params[:amazon_cloud].blank?)
        params[:amazon_cloud][:project_id] = @project.id
      else
        params[:cluster][:project_id] = @project.id
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def cluster_params
      if(!params[:data_center].blank?)
        data_center_params
      elsif(!params[:amazon_cloud].blank?)
        amazon_cloud_params
      elsif(params[:cluster][:type] == "AmazonCloud")
        params.require(:cluster).permit(:project_id, :type, :access_key, :secret_key, :ssh_identity, :region, :instance_type)
      elsif(params[:cluster][:type] == "DataCenter")
        params[:cluster][:machines] = params[:cluster][:machines].reject{ |e| e.blank? }.to_json
        params.require(:cluster).permit(:project_id, :type, :user_name, :machines, :ssh_identity)
      end
    end

    def convert_machines_json_to_array
      if ! @cluster.machines.blank?
        @cluster.machines = JSON.parse(@cluster.machines)
      end
    end

  def amazon_cloud_params
    params.require(:amazon_cloud).permit(:project_id, :type, :access_key, :secret_key, :ssh_identity, :region, :instance_type)
  end

  def data_center_params
    params[:data_center][:machines] = params[:data_center][:machines].reject{ |e| e.blank? }.to_json
    params.require(:data_center).permit(:project_id, :type, :user_name, :machines, :ssh_identity)
  end
end
