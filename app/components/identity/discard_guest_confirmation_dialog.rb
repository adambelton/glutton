module Identity
  class DiscardGuestConfirmationDialog < Shared::Base
    def view_template
      div(data: { controller: "discard-guest-confirmation-dialog" }) do
        render Shared::DestructiveButton.new(class: "ui-action-button",
          aria: { haspopup: "dialog" }, data: { action: "discard-guest-confirmation-dialog#open" }) { t("identity.entry.discard_guest") }
        tag(:dialog, class: "ui-card discard-guest-dialog",
          aria: { labelledby: "discard-guest-title", describedby: "discard-guest-description" },
          data: { discard_guest_confirmation_dialog_target: "dialog", action: "turbo:before-cache@document->discard-guest-confirmation-dialog#close" }) do
          h2(id: "discard-guest-title") { t("identity.entry.discard_guest_title") }
          p(id: "discard-guest-description") { t("identity.entry.confirm_discard_guest") }
          div(class: "ui-actions") do
            render Shared::GhostButton.new(class: "ui-action-button", autofocus: true,
              data: { action: "discard-guest-confirmation-dialog#close" }) { t("identity.entry.cancel_discard_guest") }
            render Shared::ActionForm.new(url: guest_session_path,
              method: :delete) do
              render Shared::DestructiveButton.new(type: :submit, class: "ui-action-button") { t("identity.entry.discard_guest") }
            end
          end
        end
      end
    end
  end
end
