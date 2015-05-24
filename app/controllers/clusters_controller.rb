class ClustersController < ApplicationController

  before_action :set_cluster, :except => [:index, :new, :create]

  # GET /clusters
  # GET /clusters.json
  def index
    @clusters = @project.clusters
  end

  # GET /clusters/1
  # GET /clusters/1.json
  def show
    if params[:format] == 'pem'
      send_file(@cluster.ssh_identity.path, :type => 'application/x-x509-ca-cert', :disposition => 'attachment') and return
    end
  end

  # GET /clusters/new
  def new
    @cluster = (params[:type].to_s.safe_constantize || Cluster).new
  end

  # GET /clusters/1/edit
  def edit
  end

  # POST /clusters
  # POST /clusters.json
  #
  # Sample Data:
  # data_center"=>{"title"=>"", "user_name"=>"ubuntu", "machines"=>[""]}, "type"=>"DataCenter"
  # "amazon_cloud"=>{"access_key"=>"", "secret_key"=>"", "region"=>"us-east-1", "instance_type"=>"m1.small"}, "type"=>"AmazonCloud"
  def create

    cluster_type = params[:type].to_s
    @cluster = cluster_type.safe_constantize.new(cluster_params) || Cluster.new
    @cluster.project_id = @project.id
    if @cluster.save
      redirect_to project_clusters_path(@project), flash: {success: "#{cluster_type.titlecase} cluster was successfully created."}
    else
      render :new
    end
  end

  # PATCH/PUT /clusters/1
  # PATCH/PUT /clusters/1.json
  def update
    respond_to do |format|
      if @cluster.update(cluster_params)
        format.html { redirect_to project_clusters_path(@project), flash: {success: "#{@cluster.type.to_s.titlecase} cluster was successfully updated."} }
        format.json { render :show, status: :ok, location: @cluster }
      else
        format.html { render :edit }
        format.json { render json: @cluster.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_cluster
    @cluster = Cluster.find(params[:id])
  end

  # Permissible params for cluster type
  def cluster_params
    cluster_type = params[:type].to_s
    case cluster_type
      when AmazonCloud.name
        amazon_cloud_params
      when DataCenter.name
        data_center_params
      else
        ActionController::Parameters.new
    end
  end

  def amazon_cloud_params
    params.require(:amazon_cloud).permit(:access_key, :secret_key, :ssh_identity, :region, :instance_type)
  end

  def data_center_params
    params.require(:data_center).permit(:user_name, :ssh_identity, :title, {machines: []})
  end
end
