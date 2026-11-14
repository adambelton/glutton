module Identity
  class DiscardGuestConfirmationDialog < Shared::Base
    def view_template
      render Shared::ConfirmationDialog.new(id: "discard-guest", action_label: t("identity.entry.discard_guest"),
        title: t("identity.entry.discard_guest_title"), description: t("identity.entry.confirm_discard_guest"),
        cancel_label: t("identity.entry.cancel_discard_guest"), url: guest_session_path)
    end
  end
end
