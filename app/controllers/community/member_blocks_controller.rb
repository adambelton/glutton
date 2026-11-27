module Community
  class MemberBlocksController < ApplicationController
    rescue_from Errors::MembershipRequired, Errors::PostingUnavailable, with: -> { head :forbidden }
    rescue_from Errors::MemberBlockUnavailable do
      redirect_to account_community_path, alert: t("community.member_blocks.unavailable"), status: :see_other
    end

    def create
      Membership::ManageMemberBlocks.block(**member_identifiers)
      redirect_to account_community_path, notice: t("community.member_blocks.blocked"), status: :see_other
    end

    def destroy
      Membership::ManageMemberBlocks.unblock(**member_identifiers)
      redirect_to account_community_path, notice: t("community.member_blocks.unblocked"), status: :see_other
    end

    private

    def member_identifiers
      value = params[:member_id]
      raise ActionController::BadRequest unless RecordId.valid?(value)

      { user_id: current_user.id, member_id: value.to_i }
    end
  end
end
