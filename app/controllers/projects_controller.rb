class ProjectsController < ApplicationController

  # before_action :set_project, except: [:index, :new, :create, :update_loadtest_results, :check_download_status]
  skip_before_action :set_project, only: [:index, :new, :create, :update_loadtest_results, :check_download_status]
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
    file_name = project_log_path
    if File.exist?(file_name)
      @logOffset = File.size(file_name)
    else
      @logOffset = 0
    end

    # get load_test data
    @load_tests = LoadTest.where(project_id: @project.id).reverse_chronological_list
    @last_test = @load_tests.first
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

          id_ary = params[:ids].map(&:to_i).reverse
          # save data for selected results
          result_download_data = Hash.new
          result_download_data[:test_ids] = id_ary.join(',')
          result_download_data[:project_id] = @project.id
          result_download_data[:result_type] = params[:process]
          result_download = ProjectResultDownload.new(result_download_data)
          result_download.save!

          project_results_download(params[:process], id_ary, result_download.id)

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

    file_name = project_log_path
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
    submit_process(:status) if @project.started?
    render json: state_snapshot
  end

  # get load test new results
  def update_loadtest_results
    # get load_test data
    load_tests = LoadTest.where('project_id = :projectid',
                                :projectid => params[:project_id]).reverse_chronological_list

    render(partial: 'load_tests/item', collection: load_tests)
  end

  # check status of project result download
  def check_download_status
    download_result_data = ProjectResultDownload.find(params[:request_id])
    if download_result_data.status.to_i == 1
      download_result_data.destroy!
    end

    render :text => download_result_data.status
  end

  # Indicates an error in a submitted job
  # POST /projects/1/job_error
  def job_error
    command = params[:command].to_sym
    message = params[:message]
    @project.send("#{command}_fail!", nil, message)
    head :ok
  end

  # Fetches generated reports
  # GET /projects/1/generated_reports
  def generated_reports

    files = []
    @project.generated_reports do |file_path|
      file_name = File.basename(file_path)
      files << {title: file_name, path: report_project_path(@project, file_name: file_name)}
    end

    render partial: 'generated_reports/list', object: files
  end

  # Downloads a report
  # GET /project/1/report?file_name=foo.docx
  def report
    report_file_name = params[:file_name]
    download_file_path = File.join(@project.reports_dir_path, report_file_name)
    file_type = case report_file_name
                  when /\.docx$/
                    'application/doc'
                  when /\.zip$/
                    'application/zip'
                  else
                    'application/x-octet-stream'
                end
    send_file download_file_path, :type => file_type, :disposition => 'attachment', :filename => report_file_name
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

    # target host data
    environment_data['monitoring'] = TargetHost.as_json(@project)

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

  # @return [String]
  def project_log_path
    File.join(Rails.configuration.project_setup_path, @project.project_key, 'log', Rails.configuration.project_logs_file)
  end

end
