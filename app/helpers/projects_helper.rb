module ProjectsHelper

  # @param project [Project]
  def project_status(project)
    project.status.blank? ? 'Empty' : project.status_title()
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
            data: {
                confirm: 'Are you sure you want to stop the test?\n\nYou should only do this if you have a test that is set to loop forever without a maximum duration. If you want to discard this test, try "Abort" instead.'
            },
            id: 'project_stop',
            class: stop_button_class
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
            class: abort_button_class
        }
    ]
  end

  def terminate_link_to_args
    [
        project_interpret_task_path(@project, process: 'terminate'),
        {
            data: {
                confirm: 'Are you sure you want to terminate the session?'
            },
            id: 'project_terminate',
            class: terminate_button_class
        }
    ]
  end

end
