module Community
  class PostFilmDebrief < Post
    belongs_to :film, class_name: "Registry::Film"

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
