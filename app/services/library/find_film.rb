module Library
  class FindFilm
    def self.call(user_id:, library_film_id:)
      user = User.find_by(id: user_id)
      raise IdentityUnavailable unless user&.active?

      LibraryFilm.includes(:film).find_by(user_id: user.id, id: library_film_id) || raise(FilmUnavailable)
    end
  end
end
