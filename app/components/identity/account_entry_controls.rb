module Identity
  class AccountEntryControls < Shared::Base
    def initialize(guest_entry: true)
      @guest_entry = guest_entry
    end

    def view_template
      text_link(t("ui.log_in"), new_session_path)
      text_link(t("ui.register"), new_registration_path)
      if @guest_entry
        render Shared::ActionForm.new(url: guest_session_path) do
          render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("identity.entry.try_it_out") }
        end
      end
    end
  end
end
