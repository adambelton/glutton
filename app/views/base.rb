module Views
  class Base < Shared::Base
    private

    def page(title:, narrow: false, pending_reminder: true, account_controls: true, heading_outside_card: false, heading_action: nil, **attrs, &block)
      render Shared::Layout.new(title:, pending_reminder:, account_controls:) do |heading_in_mobile_navigation|
        main(id: "main-content", tabindex: "-1", class: [ ("ui-card" unless heading_outside_card), ("ui-narrow" if narrow), attrs.delete(:class) ], **attrs) do
          heading_class = "ui-heading-in-mobile-navigation" if heading_in_mobile_navigation
          if heading_action.present?
            div(class: "ui-page-heading") do
              h1(class: heading_class) { title }
              render heading_action
            end
          else
            h1(class: heading_class) { title }
          end
          div(class: [ "ui-page-body", ("ui-card" if heading_outside_card) ], &block)
        end
      end
    end
  end
end
