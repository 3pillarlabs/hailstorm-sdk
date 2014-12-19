require 'hailstorm_setup'

class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy, :setup_project]

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

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_url, notice: 'Project was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def setup_project
    environment_data = Hash.new

    #Get test plan data for the project
    environment_data['test_plans_data'] = @project.test_plans

    #Get amazon cloud data for the project
    environment_data['amazon_clouds_data'] = @project.amazon_clouds

    #Get data center data for the project
    environment_data['data_centers_data'] = @project.data_centers

    #Submit job for project setup
    HailstormSetup.perform_async(@project.title, Rails.configuration.project_setup_path, @project.id, environment_data)
  end

  private
    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      params.require(:project).permit(:title, :status)
    end
end
