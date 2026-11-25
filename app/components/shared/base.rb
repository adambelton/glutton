module Shared
  class Base < Phlex::HTML
    include Phlex::Rails::Helpers::Routes
    include Phlex::Rails::Helpers::FormWith
    include Phlex::Rails::Helpers::ButtonTo

    register_value_helper :current_user
    register_value_helper :browsing_path
    register_value_helper :current_pending_registration
    register_value_helper :flash

    private

    def t(key, **options)
      I18n.t(key, **options, raise: true)
    end

    def text_link(text, href, **attrs)
      render RubyUI::Link.new(href:, class: "ui-link", **attrs) { text }
    end

    def submit(text)
      render Shared::PrimaryButton.new(type: :submit, class: "ui-submit") { text }
    end

    def track_form_changes(baseline:, ignored: [], controller: nil, action: nil, **data)
      data.merge(controller: [ controller, "unchanged-form" ].compact.join(" "),
        action: [ action, "input->unchanged-form#update change->unchanged-form#update" ].compact.join(" "),
        unchanged_form_baseline_value: baseline.to_json, unchanged_form_ignored_value: ignored.to_json)
    end

    def field(name:, label:, id:, type: :text, **attrs)
      div(class: "ui-field") do
        label(for: id) { label }
        render RubyUI::Input.new(type:, name:, id:, class: "ui-input", **attrs)
      end
    end

    def errors(messages)
      return if messages.blank?

      ul(role: "alert", class: "ui-errors") { messages.each { |message| li { message } } }
    end
  end
end
