module Community
  class CurationDiscussion
    PAGE_SIZE = 20
    Page = Data.define(:comments, :next_cursor)

    def initialize(curation:, film_id: nil, selected_reply_id: nil, expand_selected_branch: false)
      @curation = curation
      @film_id = film_id
      @selected_children = {}
      @expanded_parent_ids = Set.new
      select_path(selected_reply_id, expand_selected_branch:) if selected_reply_id.present?
    end

    def count_for_film(film_id)
      counts_by_film.fetch(film_id, 0)
    end

    def reply_counts(parent_ids)
      visible_comments.where(parent_id: parent_ids).group(:parent_id).count
    end

    def page(film_id:, parent_id: nil, after: nil)
      comments = visible_comments.where(parent_id:)
      if parent_id.nil?
        comments = comments.where(film_endorsement_id: @curation.film_endorsements.where(film_id:).select(:id))
      end
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

    def reveal?(film_id)
      @selected_film_id == film_id
    end

    private

    def counts_by_film
      @counts_by_film ||= begin
        authored = @curation.comments.joins(:content)
          .joins("INNER JOIN comments AS discussion_roots ON discussion_roots.id = COALESCE(comments.root_id, comments.id)")
          .joins("INNER JOIN film_endorsements ON film_endorsements.id = discussion_roots.film_endorsement_id")
        authored = authored.where(film_endorsements: { film_id: @film_id }) if @film_id.present?
        authored.group("film_endorsements.film_id").count
      end
    end

    def visible_comments
      # A removal marker is visible only while it leads to an authored descendant.
      @visible_comments ||= @curation.comments.where(<<~SQL)
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
      selected = @curation.comments.preload(content: :author).find_by(id: Integer(selected_reply_id, exception: false))
      while selected.present? && !visible_comments.exists?(selected.id)
        selected = selected.parent
      end
      return unless selected.present?

      @selected_film_id = selected.discussion_film_id
      @expanded_parent_ids.add(selected.id) if expand_selected_branch || selected.content.blank?
      while selected.present?
        @selected_children[selected.parent_id] = selected
        @expanded_parent_ids.add(selected.parent_id) if selected.parent_id.present?
        selected = selected.parent
      end
    end
  end
end
