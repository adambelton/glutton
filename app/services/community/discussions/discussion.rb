module Community
  module Discussions
    class Discussion
      PAGE_SIZE = 20
      Page = Data.define(:comments, :next_cursor)

      def initialize(post:, selected_reply_id: nil, expand_selected_branch: false, focus_selected: false)
        @post = post
        @focus_selected = focus_selected
        @selected_children = {}
        @expanded_parent_ids = Set.new
        select_path(selected_reply_id, expand_selected_branch:) if selected_reply_id.present?
      end

      def require_parent!(parent_id)
        @post.comments.find(parent_id) if parent_id.present?
      end

      def reply_counts(parent_ids)
        visible_comments.where(parent_id: parent_ids).group(:parent_id).count
      end

      def page(film_id: nil, parent_id: nil, after: nil)
        comments = parent_id.present? ? visible_comments.where(parent_id:) : roots(film_id)
        comments = comments.where("comments.id > ?", after) if after.present?
        rows = comments.order(:id).limit(PAGE_SIZE + 1).preload(content: :author).to_a
        more = rows.size > PAGE_SIZE
        rows.pop if more
        next_cursor = rows.last.id if more
        selected = @selected_children[parent_id] if after.nil?
        if selected.present? && rows.exclude?(selected)
          rows << selected
        end
        Page.new(comments: rows, next_cursor:)
      end

      def expanded?(parent)
        @expanded_parent_ids.include?(parent.id)
      end

      def focus?(comment)
        @focus_selected && @selected_comment&.id == comment.id
      end

      private

      def roots(_film_id)
        visible_comments.where(parent_id: nil)
      end

      def visible_comments
        # A removal marker is visible only while it leads to an authored descendant.
        @visible_comments ||= @post.comments.where(<<~SQL)
          EXISTS (SELECT 1 FROM comment_contents WHERE comment_id = comments.id)
          OR EXISTS (
            WITH RECURSIVE descendants(id) AS (
              SELECT child.id FROM comments AS child WHERE child.parent_id = comments.id
              UNION ALL
              SELECT child.id FROM comments AS child JOIN descendants ON child.parent_id = descendants.id
            )
            SELECT 1 FROM descendants JOIN comment_contents ON comment_contents.comment_id = descendants.id
          )
        SQL
      end

      def select_path(selected_reply_id, expand_selected_branch:)
        selected = @post.comments.preload(content: :author).find_by(id: Integer(selected_reply_id, exception: false))
        while selected.present? && !visible_comments.exists?(selected.id)
          selected = selected.parent
        end
        return unless selected.present?

        @selected_comment = selected
        @expanded_parent_ids.add(selected.id) if expand_selected_branch || selected.content.blank?
        while selected.present?
          @selected_children[selected.parent_id] = selected
          @expanded_parent_ids.add(selected.parent_id) if selected.parent_id.present?
          selected = selected.parent
        end
      end
    end
  end
end
