module Community
  class PostFilmDebrief < Post
    belongs_to :film, class_name: "Registry::Film"

    def require_view_access!(viewer:, lock: false)
      super
      watched = ::Library::LibraryFilm.watched.where(user: viewer)
      watched = watched.lock if lock
      watched.find_by!(film_id:)
    end

    def self.open_for!(film:)
      find_or_create_by!(film:)
    end

    def publish_comment(author:, body:)
      comment = comments.build(debrief_film_id: film_id)
      content = comment.build_content(author:, body:)
      return content unless content.valid?

      comment.save!
      touch
      content
    end
  end
end
