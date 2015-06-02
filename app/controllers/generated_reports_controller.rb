class GeneratedReportsController < ApplicationController

  before_action :set_file_name, except: [:index]

  def index
    respond_to do |format|
      format.html { render partial: 'generated_reports/list', object: generated_reports }
    end
  end

  def show
    download_file_path = File.join(@project.reports_dir_path, @file_name)
    file_type = case @file_name
                  when /\.docx$/
                    'application/doc'
                  when /\.zip$/
                    'application/zip'
                  else
                    'application/x-octet-stream'
                end
    send_file download_file_path, :type => file_type, :disposition => 'attachment', :filename => @file_name
  end

  def destroy
    file_path = File.join(@project.reports_dir_path, @file_name)
    File.unlink(file_path)
    respond_to do |format|
      format.html { render partial: 'generated_reports/list', object: generated_reports }
    end
  end

  private

  def file_name_to_id(file_name)
    file_name.gsub(/\./, '--')
  end

  def id_to_file_name(id)
    id.gsub('--', '.')
  end

  def set_file_name
    @file_name = id_to_file_name(params[:id])
  end

  def generated_reports
    @project.generated_reports.map do |file_path|
      file_name = File.basename(file_path)
      id = file_name_to_id(file_name)
      {
          id: id,
          title: file_name,
          path: project_generated_report_path(@project, id)
      }
    end
  end

end
