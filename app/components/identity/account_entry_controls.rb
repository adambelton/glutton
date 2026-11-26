module Identity
  class AccountEntryControls < Shared::Base
    def initialize(guest_entry: true, prominent: false)
      @guest_entry, @prominent = guest_entry, prominent
    end

    def view_template
      guest_action if @guest_entry && @prominent
      entry_link(t("ui.log_in"), new_session_path)
      entry_link(t("ui.register"), new_registration_path)
      guest_action if @guest_entry && !@prominent
    end

    private

    def guest_action
      render Shared::ActionForm.new(url: guest_session_path) do
        render Shared::PrimaryButton.new(type: :submit, class: "ui-action-button") { t("identity.entry.try_it_out") }
      end
    end

    def entry_link(label, path)
      return text_link(label, path) unless @prominent

      render RubyUI::Link.new(href: path, variant: :ghost, class: "ui-action-button") { label }
    end
  end
end
