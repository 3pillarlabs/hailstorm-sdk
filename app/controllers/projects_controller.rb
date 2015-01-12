class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy, :interpret_task, :update_status, :read_logs]

  # GET /projects
  # GET /projects.json
  def index
    @items_per_page = Rails.configuration.items_per_page
    @current_page = params[:page].blank? ? 1 : params[:page]
    @projects = Project.all.pagination(@current_page, @items_per_page)
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    file_name = File.join(Rails.configuration.project_setup_path, @project.title, "log", Rails.configuration.project_logs_file)
    if(File.exist? (file_name))
      @logs = File.read(file_name)
    else
      @logs = ""
    end
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1
  # PATCH/PUT /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def update_status
    status = 0
    case params[:status]
      when "terminate"
        status = 2
      when 'setup'
        status = 3
      when 'start'
        status = 4
      when 'stop'
        status = 5
      when 'abort'
        status = 6
    end

    if status> 0 then
      params[:project] = Hash[:status => status]
      if @project.update(project_params)
        puts "status updated successfully"
      else
        raise "Some error occur, please try again."
      end
    else
      raise "Invalid value for status!"
    end
    render nothing: true
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_url, notice: 'Project was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  #interprete gem tasks and call appropriate method
  def interpret_task
    respond_to do |format|
      case params[:process]
        when "setup"
          setup_project
          format.html { redirect_to project_path(@project, :submit_action => "setup"), notice: 'Request for project set-up has been submitted, please check again for updated status.' }
          format.json { render :show, status: :ok, location: @project }
        when "start", "stop", "abort", "terminate"
          submit_process(params[:process])
          format.html { redirect_to project_path(@project, :submit_action => params[:process]), notice: 'Request for project '+params[:process]+' has been submitted, please check again for updated status.' }
          format.json { render :show, status: :ok, location: @project }
        when "results"
          project_results
          format.html { redirect_to project_path(@project, :submit_action => "results"), notice: 'Request for project results has been submitted, please check again for updated status.' }
          format.json { render :show, status: :ok, location: @project }
        else
          format.html { redirect_to project_path(@project), notice: 'Unidentified process command.' }
          format.json { render :show, status: :ok, location: @project }
      end

    end
  end

  def read_logs
    file_name = File.join(Rails.configuration.project_setup_path, @project.title, "log", Rails.configuration.project_logs_file)
    if(File.exist? (file_name))
      render :text => File.read(file_name).gsub!(/\n/, '<br />')
    else
      render :nothing => true
    end
  end

  private
    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      params.require(:project).permit(:title, :status)
    end

    def setup_project
      environment_data = Hash.new

      #Get test plan data for the project
      environment_data['test_plans_data'] = @project.test_plans.as_json

      #Get amazon cloud data for the project
      environment_data['amazon_clouds_data'] = @project.amazon_clouds.as_json

      #Get data center data for the project
      environment_data['data_centers_data'] = @project.data_centers.as_json

      upload_directory_path = Rails.root.join(Rails.configuration.uploads_directory)

      callback = url_for(:action => 'update_status', :status => "setup")

      #Submit job for project setup
      HailstormProcess.perform_async(@project.title, Rails.configuration.project_setup_path, 'setup', @project.id, callback, upload_directory_path, environment_data)
    end

    def submit_process(process)
      puts "in "+process+" project"
      callback = url_for(:action => 'update_status', :status => process)
      HailstormProcess.perform_async(@project.title, Rails.configuration.project_setup_path, process, @project.id, callback)
    end

    def project_results
      puts "in project results"
      HailstormProcess.perform_async(@project.title, Rails.configuration.project_setup_path, 'results')
    end

end
