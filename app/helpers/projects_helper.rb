module ProjectsHelper

  # @param project [Project]
  def project_status(project)
    state_icon = case project.aasm_state.to_sym
                   when :empty
                     'glyphicon glyphicon-unchecked'
                   when :partial_configured
                     'glyphicon glyphicon-edit'
                   when :configured
                     'glyphicon glyphicon-check'
                   when :ready_start
                     'glyphicon glyphicon-send'
                   when :inactive
                     'glyphicon glyphicon-glass'
                   else
                     html = "<i class=\"fa fa-cog fa-spin\"></i> #{project.status_title}"
                     nil
                 end

    unless state_icon.nil?
      html = "<span class=\"#{state_icon}\"></span> #{project.status_title}"
    end

    html
  end

  # Determines the CSS class for task buttons based on project state
  def setup_button_class
    "btn btn-primary btn-block worker_task#{@project.may_setup? ? '' : ' disabled'}"
  end

  def start_button_class
    "btn btn-success btn-block worker_task#{@project.may_start? ? '' : ' disabled'}"
  end

  def stop_button_class
    "btn btn-warning btn-block worker_task#{@project.may_stop? ? '' : ' disabled'}"
  end

  def abort_button_class
    "btn btn-warning btn-block worker_task#{@project.may_abort? ? '' : ' disabled'}"
  end

  def terminate_button_class
    "btn btn-danger btn-block worker_task#{@project.may_terminate? ? '' : ' disabled'}"
  end

  # link_to arguments for 'Setup' button
  def setup_link_to_args
    [
        project_interpret_task_path(@project, process: 'setup'),
        {
            id: 'project_setup',
            class: setup_button_class
        }
    ]
  end

  # link_to arguments for 'Start' button
  def start_link_to_args
    [
        project_interpret_task_path(@project, process: 'start'),
        {
            id: 'project_start',
            class: start_button_class
        }
    ]
  end

  # link_to arguments for 'Stop' button
  def stop_link_to_args
    [
        project_interpret_task_path(@project, process: 'stop'),
        {
            id: 'project_stop',
            class: stop_button_class,
            'data-toggle' => 'modal',
            'data-target' => '#stop-confirm-modal'
        }
    ]
  end

  def abort_link_to_args
    [
        project_interpret_task_path(@project, process: 'abort'),
        {
            data: {
                confirm: 'Are you sure you want to abort the test?\n\nThe results from the current test will be discarded'
            },
            id: 'project_abort',
            class: abort_button_class,
            'data-toggle' => 'modal',
            'data-target' => '#abort-confirm-modal'
        }
    ]
  end

  def terminate_link_to_args
    [
        project_interpret_task_path(@project, process: 'terminate'),
        {
            id: 'project_terminate',
            class: terminate_button_class,
            'data-toggle' => 'modal',
            'data-target' => '#terminate-confirm-modal'
        }
    ]
  end

end
