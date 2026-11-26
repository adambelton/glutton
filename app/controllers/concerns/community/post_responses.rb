module Community
  module PostResponses
    module Curation
      COMMENT_ACTIONS = {
        new_reply: :new_curation_reply, create_reply: :publish_curation_reply,
        edit: :edit_curation_comment, update: :update_curation_comment, destroy: :destroy_curation_comment
      }.freeze

      def self.comment_action(action_name)
        COMMENT_ACTIONS[action_name]
      end

      def self.show(post:, viewer:, selected_reply_id:, expand_selected_branch:)
        details = Curations::ReadCuration.call(curation: post, viewer:, selected_reply_id:, expand_selected_branch:)
        Views::Community::Curation.new(**details)
      end

      def self.discussion(post:, viewer:, parent_id:, after:, film_id:)
        raise ActionController::BadRequest unless film_id.present?

        page = Discussions::BrowseCurationDiscussion.call(curation: post, film_id:, parent_id:, after:, viewer:)
        DiscussionCommentPage.new(routes: DiscussionRoutes.new(post:, film_id:), **page)
      end
    end

    module FilmDebrief
      COMMENT_ACTIONS = {
        create: :publish_debrief_comment, new_reply: :new_debrief_reply, create_reply: :publish_debrief_comment,
        edit: :edit_debrief_comment, update: :update_debrief_comment, destroy: :destroy_debrief_comment
      }.freeze

      def self.comment_action(action_name)
        COMMENT_ACTIONS[action_name]
      end

      def self.show(post:, viewer:, selected_reply_id:, expand_selected_branch:)
        discussion = Discussions::Discussion.new(post:, selected_reply_id:)
        Views::Community::FilmDebrief.new(debrief: post, discussion:, can_reply: Membership::PostingAccess.allowed?(user: viewer))
      end

      def self.discussion(post:, viewer:, parent_id:, after:, film_id:)
        discussion = Discussions::Discussion.new(post:)
        discussion.require_parent!(parent_id)
        DiscussionCommentPage.new(routes: DiscussionRoutes.new(post:), parent_id:, after:, discussion:,
          can_reply: Membership::PostingAccess.allowed?(user: viewer))
      end
    end

    RESPONSES = { "Community::PostCommunityCuration" => Curation, "Community::PostFilmDebrief" => FilmDebrief }.freeze

    def self.comment_action(post:, action_name:)
      self.for(post).comment_action(action_name)
    end

    def self.for(post)
      RESPONSES.fetch(post.class.name) { raise ActiveRecord::RecordNotFound }
    end
  end
end
