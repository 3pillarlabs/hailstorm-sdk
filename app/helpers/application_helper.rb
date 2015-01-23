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
        "ready to start"
      when 4
        "Started"
      when 5
        "Stopped"
      when 6
        "Aborted"
      else
        "Empty"
    end
  end

end
