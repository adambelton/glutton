module Identity
  class RegistrationReminder < Shared::Base
    def initialize(registration:)
      @registration = registration
    end

    def view_template
      return unless @registration

      aside(role: "status", class: "ui-reminder") do
        render PendingDetails.new(registration: @registration)
        text_link(t("identity.registration.pending_title"), registration_path)
      end
    end
  end
end
