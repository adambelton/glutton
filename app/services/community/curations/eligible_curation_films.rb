module Community
  module Curations
    class EligibleCurationFilms
      def self.call(community_user:)
        films = yield community_user.user_id
        films.select { |film| film.tmdb_details.genre_names.include?("Horror") }
      end
    end
  end
end
