module Community
  module Curations
    class BrowseEligibleCurationFilms
      def self.choices(community_user:)
        films = EligibleCurationFilms.call(community_user:) do |user_id|
          Library::CollectionManagement::BrowseWatchedFilms.films(user_id:)
        end
        films.sort_by { |film| [ film.title.downcase, film.id ] }
      end

      def self.lock_for_submission(community_user:, film_ids:)
        EligibleCurationFilms.call(community_user:) do |user_id|
          Library::CollectionManagement::BrowseWatchedFilms.films(user_id:, film_ids:, lock: true)
        end
      end
    end
  end
end
