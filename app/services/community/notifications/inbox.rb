module Community
  module Notifications
    class Inbox
      PAGE_SIZE = 20
      Page = Data.define(:items, :next_cursor)

      def initialize(viewer:)
        raise Errors::MembershipRequired unless viewer.can_view_account?

        @viewer = viewer
      end

      def unread?
        visible.unread.exists?
      end

      def page(before: nil)
        scope = before.present? ? visible.where(id: ...before) : visible
        items = scope.order(id: :desc).limit(PAGE_SIZE + 1)
          .preload(comment_content: { comment: [ :post, { film_endorsement: :film } ] }).to_a
        more = items.size > PAGE_SIZE
        items.pop if more
        Page.new(items:, next_cursor: more ? items.last.id : nil)
      end

      def open!(id:)
        notification = visible.find(id)
        content = notification.comment_content
        comment = content.comment
        Posts::ReadPost.call(id: comment.post_id, viewer: @viewer)
        MemberBlock.require_visible!(viewer_id: @viewer.id, member_id: content.community_user_id)
        notification.mark_read!
        comment
      end

      private

      def visible
        return Notification.none unless Membership::Access.allowed?(user: @viewer)

        watched_ids = Library::CollectionManagement::BrowseWatchedFilms.film_ids(user_id: @viewer.id)
        visible_posts = Post.where(type: PostCommunityCuration.sti_name)
          .or(Post.where(type: PostFilmDebrief.sti_name, film_id: watched_ids))
        blocked_by_viewer = MemberBlock.where(blocker_id: @viewer.id).select(:blocked_id)
        blocking_viewer = MemberBlock.where(blocked_id: @viewer.id).select(:blocker_id)
        Notification.where(recipient_id: @viewer.id).joins(comment_content: :comment)
          .where(comments: { post_id: visible_posts.select(:id) })
          .where.not(comment_contents: { community_user_id: blocked_by_viewer })
          .where.not(comment_contents: { community_user_id: blocking_viewer })
      end
    end
  end
end
