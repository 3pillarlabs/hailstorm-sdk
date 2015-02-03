require 'rubygems'
require 'zip'
require "open-uri"

class ProjectsController < ApplicationController
  #before_action :set_project, only: [:show, :interpret_task, :update_status, :read_logs, :check_project_status, :export_initiate, :download_results]
  before_action :set_project, except: [:index, :new, :create, :update_loadtest_results, :check_download_status]


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

    #get load_test data
    @load_tests = LoadTest.where(:project_id=>@project.id)

  end

  # GET /projects/new
  def new
    @project = Project.new
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

  #interprete gem tasks and call appropriate method
  def interpret_task
    respond_to do |format|
      case params[:process]
        when "setup"
          #update project status for Setup in progress
          params[:project] = Hash[:status => 3]
          @project.update(project_params)

          setup_project
          format.html { redirect_to project_path(@project, :submit_action => "setup"), notice: 'Request for project set-up has been submitted.' }
          format.json {render :json => {"data" => 'Request for project set-up has been submitted.'}}
        when "start", "stop", "abort", "terminate"
          submit_process(params[:process])
          format.html { redirect_to project_path(@project, :submit_action => params[:process]), notice: 'Request for project '+params[:process]+' has been submitted.' }
          format.json {render :json => {"data" => 'Request for project '+params[:process]+' has been submitted.'}}
        when "download", "export"
          #save data for selected results
          result_download_data = Hash.new
          result_download_data[:test_ids] = params[:ids]
          result_download_data[:project_id] = @project.id
          result_download_data[:result_type] = params[:process]
          result_download = ProjectResultDownload.new(result_download_data)
          result_download.save

          project_results_download(params[:process], params[:ids].split(","), result_download.id)

          format.json {render :json => {"request_id"=>result_download.id,"status"=>0}}
        else
          format.html { redirect_to project_path(@project), notice: 'Unidentified process command.' }
          format.json {render :json => {"data" => 'Unidentified process command.'}}
      end

    end
  end

  #update data on callback
  def update_status
    status = 0
    case params[:status]
      when "terminate"
        status = 2
      when 'setup'
        status = 4
      when 'start'
        status = 5
      when 'stop'
        status = 6

        #save return result data
        load_test_data = Hash.new
        load_test_data[:execution_cycle_id] = params[:execution_cycle_id]
        load_test_data[:project_id] = params[:project_id]
        load_test_data[:total_threads_count] = params[:total_threads_count]
        load_test_data[:avg_90_percentile] = params[:avg_90_percentile]
        load_test_data[:avg_tps] = params[:avg_tps]
        load_test_data[:started_at] = params[:started_at]
        load_test_data[:stopped_at] = params[:stopped_at]
        load_test = LoadTest.new(load_test_data)
        load_test.save
      when 'abort'
        status = 7
      when "download", "export"
        result_download_parms = {}
        result_download_parms[:status] = 1
        ProjectResultDownload.update(params[:request_id],result_download_parms)
    end

    if status> 0 then
      params[:project] = Hash[:status => status]
      if @project.update(project_params)
        puts "status updated successfully"
      else
        raise "Some error occur, please try again."
      end
    end
    render nothing: true
  end

  #read project logs
  def read_logs
    file_name = File.join(Rails.configuration.project_setup_path, @project.title, "log", Rails.configuration.project_logs_file)
    if(File.exist? (file_name))
      render :text => File.read(file_name).gsub!(/\n/, '<br />')
    else
      render :nothing => true
    end
  end

  #return project status to update status and operation's links
  def check_project_status
    render :text => @project.status
  end

  #get load test new results
  def update_loadtest_results
    #get load_test data
    load_tests = LoadTest.where('project_id = :projectid and id > (:resultid)',:projectid => params[:project_id], :resultid => params[:resultid])


    load_test_json_arr = []
    load_tests.each do |load_test|
      load_test_json_hash = {}
      load_test_json_hash[:id] = load_test.id
      load_test_json_hash[:execution_cycle_id] = load_test.execution_cycle_id
      load_test_json_hash[:total_threads_count] = load_test.total_threads_count
      load_test_json_hash[:avg_90_percentile] = load_test.avg_90_percentile
      load_test_json_hash[:avg_tps] = load_test.avg_tps
      load_test_json_hash[:started_at_date] = load_test.started_at.strftime("%b %e ").to_s
      load_test_json_hash[:started_at_time] = load_test.started_at.strftime("%k:%M").to_s
      load_test_json_hash[:stopped_at_date] = load_test.stopped_at.strftime("%b %e ").to_s
      load_test_json_hash[:stopped_at_time] = load_test.stopped_at.strftime("%k:%M").to_s
      load_test_json_arr << load_test_json_hash
    end
    render :json => load_test_json_arr
  end

  #check status of project result download
  def check_download_status
    download_result_data = ProjectResultDownload.find(params[:request_id])
    render :text => download_result_data.status
  end

  #prepare download based on type
  def download_results
    download_result_data = ProjectResultDownload.find(params[:request_id])
    export_id_arr = download_result_data.test_ids.split(",")

    download_report_path = File.join(Rails.configuration.project_setup_path, @project.title, "reports")

    if(download_result_data.result_type == "export")
      t = Tempfile.new("my-temp-filename-#{Time.now}")
      Zip::OutputStream.open(t.path) do |z|
        export_id_arr.each do |val|
          export_dir_path = File.join(download_report_path,"SEQUENCE-"+val)
          Dir.glob(export_dir_path+"/*").each do |item|
            title = File.basename(item,".jtl")
            title = title+"-"+val+".jtl"
            z.put_next_entry("exportreports/#{title}")
            url1 = item
            url1_data = open(url1)
            z.print IO.read(url1_data)
          end
        end
      end

      send_file t.path, :type => 'application/zip', :disposition => 'attachment', :filename => "exportreports.zip"

      t.close
    elsif(download_result_data.result_type == "download")
      start_id = export_id_arr[0]
      end_id = export_id_arr[export_id_arr.length-1]
      report_file_name = "#{@project.title}-#{start_id}-#{end_id}.docx"
      download_file_path = File.join(download_report_path,report_file_name)

      send_file download_file_path, :type=>"application/doc", :disposition => 'attachment'
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
      callback = url_for(:action => 'update_status', :status => process)
      HailstormProcess.perform_async(@project.title, Rails.configuration.project_setup_path, process, @project.id, callback)
    end

    def project_results_download(type, test_ids, request_id)
      callback = url_for(:action => 'update_status', :status => type, :request_id => request_id)
      HailstormProcess.perform_async(@project.title, Rails.configuration.project_setup_path, type, @project.id, callback, nil, nil, test_ids)
    end

end
