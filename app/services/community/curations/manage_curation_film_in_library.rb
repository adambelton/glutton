module Community
  module Curations
    class ManageCurationFilmInLibrary
      def self.add_to_watchlist(curation_id:, user_id:, film_id:)
        WithCurationNomination.call(curation_id:, user_id:, film_id:) do |viewer_id, nominated_film_id|
          Library::CollectionManagement::AddToWatchlist.call(user_id: viewer_id, film_id: nominated_film_id)
        end
      end

      def self.mark_watched(curation_id:, user_id:, film_id:)
        WithCurationNomination.call(curation_id:, user_id:, film_id:) do |viewer_id, nominated_film_id|
          Library::CollectionManagement::MarkWatched.call(user_id: viewer_id, film_id: nominated_film_id)
        end
      end
    end
  end
end
