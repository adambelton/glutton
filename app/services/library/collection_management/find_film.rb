module Library
  module CollectionManagement
    class FindFilm
      def self.call(user_id:, library_film_id:)
        user = Identity::User.find_by(id: user_id)
        raise Identity::Errors::Unavailable unless user&.active?

        LibraryFilm.includes(:film).find_by(user_id: user.id, id: library_film_id) || raise(Library::Errors::FilmUnavailable)
      end
    end
  end
end
