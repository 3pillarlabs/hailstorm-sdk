class TestPlansController < ApplicationController
  before_action :set_test_plan, :except => [:index, :new, :create]

  # GET /test_plans
  # GET /test_plans.json
  def index
    @test_plans = @project.test_plans
  end

  # GET /test_plans/1
  # GET /test_plans/1.json
  def show
    if params[:format] == 'xml'
      send_file @test_plan.jmx.path, :type => 'application/xml', :disposition => 'attachment'
    end
  end

  # GET /test_plans/new
  def new
    @test_plan = TestPlan.new
  end

  # GET /test_plans/1/edit
  def edit
    @test_plan_properties = Array.new
    test_plan = TestPlan.where(id: params[:id], project_id: params[:project_id]).take!
    test_plan_properties_json = test_plan.properties
    unless test_plan_properties_json.nil?
      @test_plan_properties = JSON.parse(test_plan_properties_json)
    end

    @test_plan_content = test_plan.content()
  end

  # POST /test_plans
  # POST /test_plans.json
  def create
    @test_plan = TestPlan.new(test_plan_params)
    @test_plan.project_id = @project.id

    respond_to do |format|
      if @test_plan.save
        format.html { redirect_to project_test_plans_path(@project), flash: {success: 'LoadTest plan was successfully created.'} }
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

    update_args = {}
    if params[:reupload].blank?
      properties_array = Array.new
      property_names = params[:test_plan]['property_name']
      property_values = params[:test_plan]['property_value']

      count = 0
      property_names.each_with_index.each do |name, index|
        if(!name.strip.empty? and !property_values[index].strip.empty?)
          properties_array[count] = {"name" => name.strip, "value" => property_values[index].strip}
          count += 1
        end
      end

      update_args[:properties] = properties_array.to_json
    else
      update_args = params.require(:test_plan).permit(:jmx)
    end

    respond_to do |format|
      if @test_plan.update(update_args)
        format.html { redirect_to project_test_plans_path(@project), flash: {success: 'Test plan was successfully updated.'} }
        format.json { render :show, status: :ok, location: @test_plan }
      else
        format.html { render :edit }
        format.json { render json: @test_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  def downloadJmx
    send_file @test_plan.jmx.path, :type => 'application/xml', :disposition => 'attachment'
  end

  def destroy
    @test_plan.jmx = nil
    respond_to do |format|
      if @test_plan.destroy
        format.html { redirect_to project_test_plans_path, flash: {success: 'File removed successfully.'} }
      else
        format.html { redirect_to project_test_plans_path, alert: "File could not be removed: #{@test_plan.errors.full_message(:jmx)}" }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_test_plan
      @test_plan = TestPlan.where(project_id: @project.id).find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def test_plan_params
      params.require(:test_plan).permit(:project_id, :status, :jmx, :properties, :property_name, :property_value)
    end

end
