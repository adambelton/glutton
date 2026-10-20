module FilmKnowledge
  class LoadDevelopmentSample
    # Identity/title metadata only, checked 20 October 2026 against:
    # https://www.themoviedb.org/movie/348-alien?language=pt-MZ
    # https://www.themoviedb.org/movie/1091-the-thing?language=es-MX
    # https://www.themoviedb.org/movie/419430-get-out
    # Release dates stay unknown until source primary release dates are verified.
    # This is development sample data, not reviewed analyses or a production seed.
    def self.call
      raise "Film sample loading is available only in development" unless Rails.env.development?

      Film.transaction do
        [
          { tmdb_id: 348, title: "Alien", metadata: { original_title: "Alien" } },
          { tmdb_id: 1091, title: "The Thing", metadata: { original_title: "The Thing" } },
          { tmdb_id: 419430, title: "Get Out", metadata: { original_title: "Get Out" } }
        ].map do |attributes|
          Film.find_or_create_by!(tmdb_id: attributes.fetch(:tmdb_id)) do |film|
            film.assign_attributes(attributes)
          end
        end
      end
    end
  end
end
