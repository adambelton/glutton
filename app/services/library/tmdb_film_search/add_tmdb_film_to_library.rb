module Library
  module TmdbFilmSearch
    class AddTmdbFilmToLibrary
      def self.call(user_id:, tmdb_id:, library_action:)
        ResolveTmdbFilmAndApplyLibraryAction.call(user_id:, tmdb_id:, library_action:) do |selected_tmdb_id|
          Registry::CatalogueMaintenance::FindOrImportTmdbFilm.call(tmdb_id: selected_tmdb_id).id
        end
      end
    end
  end
end
