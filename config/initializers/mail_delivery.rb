require_relative "../mail_delivery"

Glutton::MailDelivery.settings(environment: Rails.env).each do |name, value|
  Rails.application.config.action_mailer.public_send("#{name}=", value)
end
