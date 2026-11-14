module Identity
  class AccountNavigation < Shared::Base
    def initialize(section:)
      @section = section
    end

    def view_template
      nav(class: "account-tabs", aria: { label: t("account.sections") }) do
        a(href: account_settings_path, aria: { current: ("page" if @section == :settings) }) { t("identity.settings.title") }
        a(href: account_taste_profile_path, aria: { current: ("page" if @section == :profile) }) { t("account.profile") }
      end
    end
  end
end
