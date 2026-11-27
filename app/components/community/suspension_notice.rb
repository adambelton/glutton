module Community
  class SuspensionNotice < Shared::Base
    CONTACT_PATH = "mailto:hello@adambelton.com"

    def initialize(in_header: false)
      @in_header = in_header
    end

    def view_template
      if @in_header
        render Shared::HeaderBanner.new(message: t("community.suspensions.banner_notice"),
          link_label: t("community.suspensions.contact"), link_path: CONTACT_PATH, role: "status")
      else
        p(role: "status", class: "ui-alert community-suspension-notice mb-4") do
          plain t("community.suspensions.notice")
          plain " "
          text_link(t("community.suspensions.contact"), CONTACT_PATH)
        end
      end
    end
  end
end
