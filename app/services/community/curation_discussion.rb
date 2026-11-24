module Community
  class CurationDiscussion
    def initialize(curation:, selected_reply_id: nil, expand_selected_branch: false)
      @curation = curation
      comments = curation.comments.preload(content: :author).order(:id).to_a
      comments_by_id = comments.index_by(&:id)
      authored_comments = comments.select { |comment| comment.content.present? }

      visible_ids = Set.new
      authored_comments.each do |comment|
        while comment.present? && visible_ids.add?(comment.id)
          comment = comments_by_id[comment.parent_id]
        end
      end

      @comments_by_parent = comments.select { |comment| visible_ids.include?(comment.id) }.group_by(&:parent_id)
      @roots_by_endorsement = @comments_by_parent.fetch(nil, []).group_by(&:film_endorsement_id)
      @counts_by_root = authored_comments.group_by { |comment| comment.root_id || comment.id }.transform_values(&:size)

      selected_reply = comments_by_id[Integer(selected_reply_id, exception: false)]
      while selected_reply.present? && !visible_ids.include?(selected_reply.id)
        selected_reply = comments_by_id[selected_reply.parent_id]
      end
      @expanded_parent_ids = Set.new
      if selected_reply.present?
        @selected_root_id = selected_reply.root_id || selected_reply.id
        @expanded_parent_ids.add(selected_reply.id) if expand_selected_branch || selected_reply.content.blank?
        parent = comments_by_id[selected_reply.parent_id]
        while parent.present? && @expanded_parent_ids.add?(parent.id)
          parent = comments_by_id[parent.parent_id]
        end
      end
    end

    def roots(endorsements)
      endorsements.flat_map { |endorsement| @roots_by_endorsement.fetch(endorsement.id, []) }
    end

    def replies(parent)
      @comments_by_parent.fetch(parent.id, [])
    end

    def count(roots)
      roots.sum { |root| @counts_by_root.fetch(root.id, 0) }
    end

    def endorsements_for_film(film_id)
      @curation.film_endorsements.where(film_id:)
    end

    def count_for_film(film_id)
      count(roots(endorsements_for_film(film_id)))
    end

    def expanded?(parent)
      @expanded_parent_ids.include?(parent.id)
    end

    def reveal?(roots)
      roots.any? { |root| root.id == @selected_root_id }
    end
  end
end
