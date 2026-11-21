module Identity
  class AccountNavigation < Shared::Base
    def initialize(section:)
      @section = section
    end

    def view_template
      nav(class: "account-tabs", aria: { label: t("account.sections") }) do
        a(href: account_settings_path, aria: { current: ("page" if @section == :settings) }) { t("identity.settings.title") }
        a(href: account_taste_profile_path, aria: { current: ("page" if @section == :profile) }) { t("account.profile") }
        if Community::PreviewAccess.allowed?(user: current_user)
          a(href: account_community_path, aria: { current: ("page" if @section == :community) }) { t("community.title") }
        else
          render Shared::LockedNavigationLink.new(label: t("community.title"), tooltip: t("community.coming_soon"), tooltip_id: "account-community-tooltip")
        end
      end
    end
  end
end
