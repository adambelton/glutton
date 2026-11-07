module Views
  class Base < Shared::Base
    private

    def page(title:, narrow: false, pending_reminder: true, account_controls: true, heading_outside_card: false, **attrs, &block)
      render Shared::Layout.new(title:, pending_reminder:, account_controls:) do
        main(id: "main-content", tabindex: "-1", class: [ ("ui-card" unless heading_outside_card), ("ui-narrow" if narrow), attrs.delete(:class) ], **attrs) do
          h1 { title }
          div(class: [ "ui-page-body", ("ui-card" if heading_outside_card) ], &block)
        end
      end
    end
  end
end
