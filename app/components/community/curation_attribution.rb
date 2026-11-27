module Community
  class CurationAttribution < Shared::Base
    def initialize(curation:, class_name:, linked: false)
      @curation, @class_name, @linked = curation, class_name, linked
      @community_user = curation.community_user
    end

    def view_template
      if Membership::MemberVisibility.hidden?(viewer: current_user, blockable: @curation)
        return render GluttonIdentity.new(class_name: @class_name)
      end

      div(class: @class_name) do
        if @community_user.present?
          render MemberAvatar.new(community_user: @community_user)
          if @linked
            render MemberBylineName.new(community_user: @community_user)
          else
            strong { @community_user.community_username.presence || t("community.curations.member") }
          end
        else
          plain t("community.curation_protection.unattributed")
        end
      end
    end
  end
end
