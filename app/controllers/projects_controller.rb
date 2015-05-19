require 'rubygems'
require 'zip'
require 'open-uri'
require 'json'

class ProjectsController < ApplicationController

  before_action :set_project, except: [:index, :new, :create, :update_loadtest_results, :check_download_status]
  skip_before_action :verify_authenticity_token, only: [:job_error, :update_status]

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
    file_name = File.join(Rails.configuration.project_setup_path, @project.title, 'log', Rails.configuration.project_logs_file)
    if File.exist?(file_name)
      @logs = File.read(file_name)
    else
      @logs = ''
    end

    # get load_test data
    @load_tests = LoadTest.where(project_id: @project.id)
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

    command = params[:process].to_sym
    respond_to do |format|
      case command
        when :setup
          setup_project() if @project.may_setup?
          @project.setup! # TODO refactor setup_project as a :before callback to event

          format.html { redirect_to project_path(@project, :submit_action => 'setup'), notice: 'Request for project set-up has been submitted.' }
          format.json {render :json => {'data' => 'Request for project set-up has been submitted.'}.merge(state_snapshot)}
        when :start, :stop, :abort, :terminate
          submit_process(command) if @project.send("may_#{command}?")
          @project.send("#{command}!") # TODO refactor as a :before callback to events
          format.html { redirect_to project_path(@project, :submit_action => params[:process]), notice: 'Request for project '+params[:process]+' has been submitted.' }
          format.json {render :json => {'data' => 'Request for project '+params[:process]+' has been submitted.'}.merge(state_snapshot)}
        when :download, :export
          # save data for selected results
          result_download_data = Hash.new
          result_download_data[:test_ids] = params[:ids]
          result_download_data[:project_id] = @project.id
          result_download_data[:result_type] = params[:process]
          result_download = ProjectResultDownload.new(result_download_data)
          result_download.save!

          project_results_download(params[:process], params[:ids].split(','), result_download.id)

          format.json {render :json => {'request_id' => result_download.id, 'status' => 0}}
        else
          format.html { redirect_to project_path(@project), notice: 'Unidentified process command.' }
          format.json {render :json => {'data' => 'Unidentified process command.'}}
      end

    end
  end

  # update data on callback
  def update_status

    command = params[:status].to_sym
    case command
      when :setup, :start, :abort, :terminate
        @project.send("#{command}_done!")
      when :stop
        @project.stop_done!
        # save return result data
        raw_data = params[:data]
        results = JSON.parse(raw_data)
        results.each {|result| LoadTest.create!(result.merge(project_id: @project.id))}

      when :download, :export
        result_download_parms = {}
        result_download_parms[:status] = 1
        ProjectResultDownload.update(params[:request_id], result_download_parms)

      when :status
        status_data = params[:status_data]
        unless status_data.blank?
          if JSON.parse(status_data).empty?
            if @project.may_stop?
              submit_process(:stop)
              @project.stop! # TODO refactor as a :before callback to events
            end
          end
        end
      else
        raise "Unknown command for status update: #{command}"
    end

    flash[:notice] = "#{command} completed successfully!"
    render nothing: true
  end

  # read project logs
  def read_logs

    file_name = File.join(Rails.configuration.project_setup_path, @project.project_key, 'log', Rails.configuration.project_logs_file)
    file_contents = nil
    if File.exist?(file_name)
      offset = (params[:offset] || 0).to_i
      File.open(file_name) { |f| f.seek(offset) if offset > 0; file_contents = f.read(); }
    end

    if not file_contents.blank?
      render text: file_contents
    else
      render nothing: true
    end
  end

  # project status to update status and operation's links
  # if state_reason is not empty, it is the error message with last command.
  def check_project_status
    submit_process(:status)
    render json: state_snapshot
  end

  #get load test new results
  def update_loadtest_results
    #get load_test data
    load_tests = LoadTest.where('project_id = :projectid and id > (:resultid)',
                                :projectid => params[:project_id],
                                :resultid => params[:resultid])


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
    export_id_arr = download_result_data.test_ids.split(',')

    download_report_path = File.join(Rails.configuration.project_setup_path, @project.project_key, 'reports')

    if download_result_data.result_type == 'export'
      t = Tempfile.new("my-temp-filename-#{Time.now}")
      Zip::OutputStream.open(t.path) do |z|
        export_id_arr.each do |val|
          export_dir_path = File.join(download_report_path, "SEQUENCE-#{val}")
          Dir.glob(export_dir_path + '/*').each do |item|
            # title = File.basename(item, '.jtl')
            # title = title+"-"+val+".jtl"
            title = "#{File.basename(item, '.jtl')}-#{val}.jtl"
            z.put_next_entry("exportreports/#{title}")
            url1 = item
            url1_data = open(url1)
            z.print IO.read(url1_data)
          end
        end
      end

      send_file t.path, :type => 'application/zip', :disposition => 'attachment', :filename => 'exportreports.zip'
      t.close

    elsif download_result_data.result_type == 'download'
      start_id = export_id_arr[0]
      end_id = export_id_arr[export_id_arr.length - 1]
      report_file_name = "#{@project.project_key}-#{start_id}-#{end_id}.docx"
      download_file_path = File.join(download_report_path, report_file_name)

      send_file download_file_path, :type => 'application/doc', :disposition => 'attachment', :filename => report_file_name
    else
      render :nothing => true
    end
  end

  # Indicates an error in a submitted job
  # POST /projects/1/job_error
  def job_error
    command = params[:command].to_sym
    message = params[:message]
    @project.send("#{command}_fail!", nil, message)
    head :ok
  end

  private
  # Never trust parameters from the scary internet, only allow the white list through.
  def project_params
    params.require(:project).permit(:title, :status)
  end

  def setup_project

    upload_directory_path = Rails.root.join(Rails.configuration.uploads_directory)

    callback = url_for(:action => 'update_status', :status => 'setup')

    # Submit job for project setup
    HailstormProcess.perform_async(@project.project_key, Rails.configuration.project_setup_path, 'setup', @project.id, callback, upload_directory_path, env_data_for_worker, nil, error_callback)
  end

  def env_data_for_worker
    environment_data = Hash.new

    # Get test plan data for the project
    environment_data['test_plans_data'] = @project.test_plans.as_json

    # Get amazon cloud data for the project
    environment_data['amazon_clouds_data'] = @project.amazon_clouds.as_json

    # Get data center data for the project
    environment_data['data_centers_data'] = @project.data_centers.as_json
    environment_data
  end

  def submit_process(process)
    upload_directory_path = Rails.root.join(Rails.configuration.uploads_directory)
    callback = url_for(:action => 'update_status', :status => process.to_s)
    HailstormProcess.perform_async(@project.project_key, Rails.configuration.project_setup_path, process.to_s, @project.id, callback, upload_directory_path, env_data_for_worker, nil, error_callback)
  end

  def project_results_download(type, test_ids, request_id)
    callback = url_for(:action => 'update_status', :status => type, :request_id => request_id)
    HailstormProcess.perform_async(@project.project_key, Rails.configuration.project_setup_path, type, @project.id, callback, nil, nil, test_ids, error_callback)
  end

  def error_callback
    url_for(action: 'job_error')
  end

  def state_snapshot
    {
        state_code: @project.aasm.current_state,
        state_title: @project.status_title,
        state_reason: @project.state_reason,
        state_triggers: {
          setup: @project.may_setup?,
          start: @project.may_start?,
          stop:  @project.may_stop?,
          abort: @project.may_abort?,
          term:  @project.may_terminate?
        },
        any_op_in_progress: @project.anything_in_progress?
    }
  end

end
