class TestPlansController < ApplicationController
  before_action :set_test_plan, only: [:show, :edit, :update, :destroy]
  before_filter :check_for_cancel, :only => [:create, :update, :new]

  # GET /test_plans
  # GET /test_plans.json
  def index
    @test_plan = TestPlan.new
    @items_per_page = Rails.configuration.items_per_page
    @current_page = params[:page].blank? ? 1 : params[:page]
    @test_plans = @test_plan.getProjectTestPlans(params[:project_id]).pagination(@current_page, @items_per_page)
    @project = Project.find(params[:project_id])
  end

  # GET /test_plans/1
  # GET /test_plans/1.json
  def show
  end

  # GET /test_plans/new
  def new
    @test_plan = TestPlan.new
    @project = Project.find(params[:project_id])
  end

  # GET /test_plans/1/edit
  def edit
  end

  # POST /test_plans
  # POST /test_plans.json
  def create
    @test_plan = TestPlan.new(test_plan_params)
    @test_plan.project_id = params[:project_id]
    @project_name = Project.find(params[:project_id])

    respond_to do |format|
      if @test_plan.save
        format.html { redirect_to :test_plan, notice: 'Test plan was successfully created.' }
        format.json { render :show, status: :created, location: @test_plan }
      else
        format.html { render :new }
        format.json { render json: @test_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /test_plans/1
  # PATCH/PUT /test_plans/1.json
  def update
    respond_to do |format|
      if @test_plan.update(test_plan_params)
        format.html { redirect_to @test_plan, notice: 'Test plan was successfully updated.' }
        format.json { render :show, status: :ok, location: @test_plan }
      else
        format.html { render :edit }
        format.json { render json: @test_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  def downloadJmx
    project = Project.find(params[:project_id])
    project_attachment = ProjectAttachment.find(params[:id])
    project_attachment.title = project.title
    send_file project_attachment.attachment.path, :type => "application/xml", :disposition => 'attachment'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_test_plan
      @test_plan = TestPlan.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def test_plan_params
      params.require(:test_plan).permit(:project_id, :status, :jmx, :properties)
    end

    def check_for_cancel
      if params[:commit] == "Cancel"
        redirect_to my_page_path
      end
    end
end
