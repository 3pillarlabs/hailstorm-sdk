module ApplicationHelper

  def bootstrap_class_for(flash_type)
    case flash_type
      when 'success'
        'alert-success'
      when 'error'
        'alert-error'
      when 'alert'
        'alert-block'
      when 'notice'
        'alert-info'
      else
        flash_type.to_s
    end
  end

  def flash_messages(opts = {})
    flash.each do |msg_type, message|
      concat(content_tag(:div, class: "alert #{bootstrap_class_for(msg_type)} alert-dismissible", role: 'alert') {
               concat(content_tag(:button, class: 'close', data: { dismiss: 'alert' }, type: 'button', aria: {label: 'Close'}) {
                        content_tag(:span, '&times;', {aria: {hidden: true}}, false)
                      })
               concat(message)
             })
    end
    nil
  end

end
