module Admin
  class Dashboard < Shared::Base
    def initialize(title:, resource: nil, heading: true, back_to: nil, back_label: nil)
      @title, @resource, @heading = title, resource, heading
      @back_to, @back_label = back_to, back_label
    end

    def view_template
      render Shared::Document.new(title: @title, body_class: "admin-page") do
        a(href: "#main-content", class: "skip-link") { t("ui.skip") }
        if current_user&.superuser?
          render Navigation.new(resource: @resource)
        end
        main(id: "main-content", class: [ "admin-content", ("admin-record" if @back_to.present?) ], tabindex: "-1") do
          div(class: "ui-notifications") do
            render Shared::Toast.new(message: flash[:notice]) if flash[:notice].present?
            p(role: "alert", class: "admin-alert") { flash[:alert] } if flash[:alert].present?
          end
          if @back_to.present?
            a(href: @back_to, class: "admin-back") do
              span(aria: { hidden: "true" }) { "←" }
              span { @back_label }
            end
          end
          h1(class: ("sr-only" unless @heading)) { @title }
          yield
        end
      end
    end
  end
end
