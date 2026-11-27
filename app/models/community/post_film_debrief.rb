module Community
  class PostFilmDebrief < Post
    belongs_to :film, class_name: "Registry::Film"

    def require_view_access!(viewer:)
      super
      raise ActiveRecord::RecordNotFound unless yield(viewer.id, film_id).present?
    end

    def self.open_for!(film:)
      find_or_create_by!(film:)
    end

    def publish_comment(community_user:, body:)
      comment = comments.build(debrief_film_id: film_id)
      content = comment.build_content(community_user:, body:)
      return content unless content.valid?

      comment.save!
      touch
      content
    end
  end
end
