module LoadTestsHelper

  def inactivate_link_to_args(item)
    [
        project_load_test_path(@project, item),
        method: :delete,
        remote: true,
        class: 'text-muted load-result-excluder',
        data: {
            confirm: 'You are about to inactivate this result and it will not appear in future reports. The result can be reactivated later if needed. Proceed?'
        },
        title: 'Exclude (inactivate)'
    ]
  end

  def reactivate_link_to_args(item)
    [
        project_load_test_path(@project, item),
        method: :patch,
        remote: true,
        data: {
            params: {
                load_test: {active: true}
            }.to_json
        },
        class: 'text-success load-result-includer',
        title: 'Include (reactivate)'
    ]
  end
end
