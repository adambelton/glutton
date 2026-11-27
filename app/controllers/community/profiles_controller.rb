module Community
  class ProfilesController < ApplicationController
    before_action :require_member_access
    before_action :require_participation, only: [ :change_username, :choose_avatar ]

    rescue_from Errors::CodeOfConductRequired do
      redirect_to account_community_path, alert: t("community.conduct.profile_acceptance_required"), status: :see_other
    end
    rescue_from Errors::MembershipRequired, with: -> { head :forbidden }
    rescue_from Errors::ParticipationSuspended do
      redirect_to account_community_path, status: :see_other
    end

    def show
      render_profile(editing_username: params[:edit] == "username", editing_avatar: params[:edit] == "avatar")
    end

    def change_username
      community_username = params.permit(:community_username)[:community_username]
      settings.change_community_username(community_username: community_username.is_a?(String) ? community_username : nil)
      redirect_to account_community_path, notice: t("community.profile.username.saved"), status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      raise if error.record.errors[:community_username].empty?

      render_profile(editing_username: true, form_username: error.record.community_username,
        username_errors: error.record.errors.full_messages_for(:community_username), status: :unprocessable_content)
    end

    def choose_avatar
      preset = params.permit(:community_avatar_preset)[:community_avatar_preset]
      settings.choose_community_avatar(preset: preset.is_a?(String) ? preset : nil)
      redirect_to account_community_path, notice: t("community.profile.avatar.saved"), status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      raise if error.record.errors[:community_avatar_preset].empty?

      render_profile(editing_avatar: true, avatar_errors: error.record.errors.full_messages_for(:community_avatar_preset), status: :unprocessable_content)
    end

    private

    def settings
      Membership::ManageProfile.new(community_user: current_user.community_user)
    end

    def require_member_access
      response.headers["Cache-Control"] = "no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      Membership::Access.require!(user: current_user)
    end

    def require_participation
      Membership::Access.require_participation!(user: current_user)
    end

    def render_profile(editing_username: false, form_username: current_user.community_user&.community_username, username_errors: [],
      editing_avatar: false, avatar_errors: [], status: :ok)
      render Views::Community::Profile.new(community_user: current_user.community_user,
        editing_username:, form_username:, username_errors:, editing_avatar:, avatar_errors:), status:
    end
  end
end
