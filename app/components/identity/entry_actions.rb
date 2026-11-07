module Identity
  class EntryActions < Shared::Base
    def initialize(guest_entry: true)
      @guest_entry = guest_entry
    end

    def view_template
      text_link(t("ui.log_in"), new_session_path)
      text_link(t("ui.register"), new_registration_path)
      if @guest_entry
        render Shared::ActionButton.new(text: t("identity.entry.try_it_out"), url: guest_session_path)
      end
    end
  end
end
