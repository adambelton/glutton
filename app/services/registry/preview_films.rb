module Registry
  class PreviewFilms
    def self.call(tmdb_ids:)
      films = Film.where(tmdb_id: tmdb_ids).index_by(&:tmdb_id)
      tmdb_ids.filter_map { |tmdb_id| films[tmdb_id] }
    end
  end
end
