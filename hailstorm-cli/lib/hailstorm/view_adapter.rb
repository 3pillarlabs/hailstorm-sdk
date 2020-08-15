require 'hailstorm'
require 'action_view'

# Mixin provides methods to make it easier to work with ActionView.
module Hailstorm::ViewAdapter

  # @param [String] name Template file name (user.text.erb) or path segment (users/list.text.erb)
  # @param [String] prefix Path to prefix the ``name``. The template should exist at ``"#{prefix}/#{name}"``
  # @param [Symbol] format A supported ActionView format symbol such as :text, :xml, :json and others
  # @param [Hash{Symbol->any}] assigns Map of template referenced variable names to values.
  # @param [Symbol] handler A supported ActionView handler.
  # @return [String] The rendered output
  def render_template(name:, prefix:, format:, assigns: {}, handler: :erb)
    lookup_context = ActionView::LookupContext.new([prefix])
    engine = ActionView::Base.with_empty_template_cache.new(lookup_context)
    engine.assign(assigns)
    engine.render(template: name, formats: [format.to_sym], handlers: [handler.to_sym])
  end
end
