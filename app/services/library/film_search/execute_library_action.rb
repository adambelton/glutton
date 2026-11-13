module Library
  module FilmSearch
    class ExecuteLibraryAction
      def self.call(user_id:, tmdb_id:, library_action:)
        film_id = yield tmdb_id
        library_action.call(user_id:, film_id:)
      end
    end
  end
end
