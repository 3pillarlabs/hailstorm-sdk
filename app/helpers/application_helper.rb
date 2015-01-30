module ApplicationHelper
  def bootstrap_class_for flash_type
    case flash_type
      when "success"
        "alert-success"
      when "error"
        "alert-error"
      when "alert"
        "alert-block"
      when "notice"
        "alert-info"
      else
        flash_type.to_s
    end
  end

  def flash_messages(opts = {})
    flash.each do |msg_type, message|
      concat(content_tag(:div, message, class: "alert #{bootstrap_class_for(msg_type)} fade in") do
        concat content_tag(:button, 'x', class: "close", data: { dismiss: 'alert' })
        concat message
      end)
    end
    nil
  end

  def project_status(status)
    case status
      when 1
        "Partial Configured"
      when 2
        "Configured"
      when 3
        "Setup in progress"
      when 4
        "Ready to start"
      when 5
        "Started"
      when 6
        "Stopped"
      when 7
        "Aborted"
      else
        "Empty"
    end
  end

end
