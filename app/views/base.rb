module Views
  class Base < Shared::Base
    private

    def page(title:, narrow: false, pending_reminder: true, heading_outside_card: false, heading_action: nil, back_to: nil, back_label: nil, **attrs, &block)
      render Shared::Layout.new(title:, pending_reminder:) do |heading_in_mobile_navigation|
        page_back(back_label, back_to, above: true) if back_to.present? && !heading_outside_card
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
          page_back(back_label, back_to) if back_to.present? && heading_outside_card
        end
      end
    end

    def page_back(label, path, above: false)
      div(class: [ "ui-secondary-links", ("ui-page-back-above" if above) ]) { text_link(label, path) }
    end
  end
end
