module Library
  module FilmSearch
    class AddToLibraryFromSearch
      def self.call(user_id:, tmdb_id:, library_action:)
        ExecuteLibraryAction.call(user_id:, tmdb_id:, library_action:) do |selected_tmdb_id|
          Registry::CatalogueMaintenance::FindOrImportTmdbFilm.call(tmdb_id: selected_tmdb_id).id
        end
      end
    end
  end
end
