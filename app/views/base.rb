module Views
  class Base < UI::Base
    private

    def page(title:, narrow: false, pending_reminder: true, account_controls: true, **attrs, &block)
      render UI::Layout.new(title:, pending_reminder:, account_controls:) do
        main(id: "main-content", tabindex: "-1", class: [ "ui-card", ("ui-narrow" if narrow), attrs.delete(:class) ], **attrs) do
          h1 { title }
          div(class: "ui-page-body", &block)
        end
      end
    end
  end
end
