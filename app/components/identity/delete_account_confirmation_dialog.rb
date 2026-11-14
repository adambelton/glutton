module Identity
  class DeleteAccountConfirmationDialog < Shared::Base
    def view_template
      label = t("identity.settings.delete_title")
      render Shared::ConfirmationDialog.new(id: "delete-account", action_label: label, title: label,
        description: t("identity.settings.delete_description"), cancel_label: t("identity.settings.cancel"), url: account_path)
    end
  end
end
