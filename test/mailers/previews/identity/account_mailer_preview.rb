module Identity
  class AccountMailerPreview < ActionMailer::Preview
    def confirmation
      AccountMailer.confirmation(recipient: "reader@example.test", confirmation_url: "https://example.test/confirmation?token=preview")
    end

    def password_reset
      AccountMailer.password_reset(recipient: "reader@example.test", reset_url: "https://example.test/password/reset?token=preview")
    end
  end
end
