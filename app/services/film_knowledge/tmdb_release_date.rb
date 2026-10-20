module FilmKnowledge
  class TmdbReleaseDate
    def self.parse(value)
      return if value.nil? || value == ""

      unless value.is_a?(String) && value.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
        raise InvalidTmdbResponse, "TMDB returned an invalid release date"
      end

      Date.iso8601(value)
    rescue Date::Error
      raise InvalidTmdbResponse, "TMDB returned an invalid release date", cause: nil
    end
  end
end
