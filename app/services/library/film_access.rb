module Library
  # Shared access/lock order for Library's two film operations.
  class FilmAccess
    def self.call(user:, film:)
      raise IdentityUnavailable, "An active identity is required" unless user&.persisted?

      LibraryFilm.transaction do
        owner = User.lock.find_by(id: user.id)
        raise IdentityUnavailable, "An active identity is required" unless owner&.active?
        unless film&.persisted? && Film.exists?(film.id)
          raise FilmUnavailable, "Film is unavailable"
        end
        yield owner
      end
    end
  end
end
