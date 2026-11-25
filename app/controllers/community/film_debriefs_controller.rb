module Community
  class FilmDebriefsController < ApplicationController
    include FilmDebriefControllerAccess

    def show
      debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: current_user, film_id:)
      discussion = Discussions::Discussion.new(post: debrief, selected_reply_id: params[:reply])
      render Views::Community::FilmDebrief.new(debrief:, discussion:, can_reply: Membership::PostingAccess.allowed?(user: current_user))
    end

    def create
      debrief = FilmDebriefs::OpenFilmDebrief.call(member_id: current_user.id, film_id:)
      redirect_to community_film_debrief_path(debrief.film_id), status: :see_other
    end

    def discussion
      parent_id = discussion_id(params[:parent_id]) if params.key?(:parent_id)
      after = discussion_id(params[:after]) if params.key?(:after)
      debrief = FilmDebriefs::BrowseFilmDebriefs.detail(viewer: current_user, film_id:)
      debrief.comments.find(parent_id) if parent_id.present?
      render DiscussionCommentPage.new(routes: DebriefDiscussionRoutes.new(debrief:), parent_id:, after:,
        discussion: Discussions::Discussion.new(post: debrief), can_reply: Membership::PostingAccess.allowed?(user: current_user)), content_type: Mime[:html]
    end
  end
end
