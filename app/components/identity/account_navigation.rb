module Identity
  class AccountNavigation < Shared::Base
    def initialize(section:)
      @section = section
    end

    def view_template
      render Shared::NavigationTabs.new(label: t("account.sections"), css_class: "account-tabs") do
        a(href: account_settings_path, aria: { current: ("page" if @section == :settings) }) { t("identity.settings.title") }
        a(href: account_taste_profile_path, aria: { current: ("page" if @section == :profile) }) { t("account.profile") }
        a(href: account_community_path, aria: { current: ("page" if @section == :community) }) { t("community.title") }
      end
    end
  end
end
