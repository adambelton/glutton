module Library
  class ActionConfirmationDialog < Shared::Base
    def view_template
      tag(:dialog, id: "library-action-confirmation", class: "ui-card ui-confirmation-dialog",
        aria: { labelledby: "library-action-confirmation-title", describedby: "library-action-confirmation-film" },
        data: { controller: "library-action-confirmation",
                action: "click@document->library-action-confirmation#preview click->library-action-confirmation#keepSearchOpen " \
                        "close->library-action-confirmation#reset turbo:before-cache@document->library-action-confirmation#close" }) do
        h2(id: "library-action-confirmation-title", data: { library_action_confirmation_target: "title" })
        p(id: "library-action-confirmation-film", data: { library_action_confirmation_target: "film" })
        div(class: "ui-actions ui-actions-fixed") do
          render Shared::GhostButton.new(class: "ui-action-button", autofocus: true,
            data: { action: "library-action-confirmation#close" }) { t("library.confirmation.cancel") }
          render Shared::PrimaryButton.new(class: "ui-action-button",
            data: { action: "library-action-confirmation#confirm" }) { t("library.confirmation.confirm") }
        end
      end
    end
  end
end
