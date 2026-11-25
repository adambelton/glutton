module Community
  class PostFilmDebrief < Post
    belongs_to :film, class_name: "Registry::Film"

    def self.open_for!(film:)
      find_or_create_by!(film:)
    end
  end
end
