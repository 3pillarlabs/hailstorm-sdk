class TestPlansController < ApplicationController
  before_action :set_test_plan, only: [:show, :edit, :update]
  before_filter :set_project, :only => [:index, :create, :update, :new, :edit]

  # GET /test_plans
  # GET /test_plans.json
  def index
    @test_plan = TestPlan.new
    @items_per_page = Rails.configuration.items_per_page
    @current_page = params[:page].blank? ? 1 : params[:page]
    @test_plans = @test_plan.getProjectTestPlans(params[:project_id]).pagination(@current_page, @items_per_page)
  end

  # GET /test_plans/1
  # GET /test_plans/1.json
  def show
  end

  # GET /test_plans/new
  def new
    @test_plan = TestPlan.new
  end

  # GET /test_plans/1/edit
  def edit
    test_plan = TestPlan.new
    @test_plan_properties = test_plan.getTestPlanProperties(params[:id])
    #:todo remove edit from set_test_plan
  end

  # POST /test_plans
  # POST /test_plans.json
  def create
    @test_plan = TestPlan.new(test_plan_params)
    @test_plan.project_id = params[:project_id]

    respond_to do |format|
      if @test_plan.save
        format.html { redirect_to :project_test_plans, notice: 'Test plan was successfully created.' }
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
    properties_array = Array.new
    property_names = params[:test_plan]['property_name']
    property_values = params[:test_plan]['property_value']

    count =0
    while property_names[count] != nil and property_values[count] != nil
      properties_array[count] = {"name" => property_names[count], "value" => property_values[count]}
      count += 1
    end

    respond_to do |format|
      if @test_plan.update(:properties => properties_array.to_json)
        format.html { redirect_to :project_test_plans, notice: 'Test plan was successfully updated.' }
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
      params.require(:test_plan).permit(:project_id, :status, :jmx, :properties, :property_name, :property_value)
    end

    def set_project
      if(params.has_key?(:project_id))
        @project = Project.find(params[:project_id])
      end
    end
end
