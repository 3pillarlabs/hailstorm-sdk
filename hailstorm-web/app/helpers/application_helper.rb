module ApplicationHelper

  def bootstrap_class_for(flash_type)
    case flash_type
      when 'success'
        'alert-success'
      when 'error'
        'alert-danger'
      when 'alert'
        'alert-warning'
      when 'notice'
        'alert-info'
      else
        flash_type.to_s
    end
  end

  def glyphicon_for(msg_type)
    icon = case msg_type.to_sym
             when :success
               'glyphicon-ok-sign'
             when :error
               'glyphicon-remove-sign'
             when :alert
               'glyphicon-warning-sign'
             else
               'glyphicon-info-sign'
           end

    "glyphicon #{icon}"
  end

  def flash_messages(opts = {})
    flash.each do |msg_type, message|
      concat(content_tag(:div, class: "alert #{bootstrap_class_for(msg_type)} alert-dismissible", role: 'alert') {
               concat(content_tag(:button, class: 'close', data: {dismiss: 'alert'}, type: 'button', aria: {label: 'Close'}) {
                        content_tag(:span, '&times;', {aria: {hidden: true}}, false)
                      })
               concat(content_tag(:span, '', {class: glyphicon_for(msg_type)}))
               concat(" #{message}")
             })
    end
    nil
  end

  # @param [ActiveRecord::Base] model
  # @param [Symbol] attribute
  def errors_if_present(model, attribute)
    if model.errors.include?(attribute)
      concat(content_tag(:p, {class: 'text-danger', aria: {role: 'alert'}}, true) {
               concat(content_tag(:span, '', class: 'glyphicon glyphicon-exclamation-sign', aria: {hidden: 'true'}))
               concat(content_tag(:span, 'Error:', class: 'sr-only'))
               concat(' ')
               concat(model.errors.full_messages_for(attribute).join('. '))
             })
    end
    nil
  end

end
