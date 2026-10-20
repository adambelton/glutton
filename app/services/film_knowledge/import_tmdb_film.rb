module FilmKnowledge
  class ImportTmdbFilm
    def self.call(tmdb_id:, client: TmdbClient)
      raise InvalidTmdbId, "TMDB ID must be a positive Integer" unless tmdb_id.is_a?(Integer) && tmdb_id.positive?
      existing = Film.find_by(tmdb_id:)
      return existing if existing

      payload = client.movie(tmdb_id:)
      unless payload.is_a?(Hash) && payload["id"].is_a?(Integer) && payload["id"] == tmdb_id &&
          payload["title"].is_a?(String) && payload["title"].present? &&
          (payload["original_title"].nil? || payload["original_title"].is_a?(String))
        raise InvalidTmdbResponse, "TMDB returned invalid movie data"
      end

      date = payload["release_date"]
      unless date.nil? || date == ""
        unless date.is_a?(String) && date.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
          raise InvalidTmdbResponse, "TMDB returned an invalid release date"
        end
        begin
          date = Date.iso8601(date)
        rescue Date::Error
          raise InvalidTmdbResponse, "TMDB returned an invalid release date", cause: nil
        end
      end
      metadata = { "tmdb" => { "fetched_at" => Time.current.utc.iso8601, "language" => "en-US" } }
      metadata["original_title"] = payload["original_title"] unless payload["original_title"].nil?
      # A savepoint lets duplicate-key recovery also work within a caller transaction.
      Film.transaction(requires_new: true) do
        Film.create!(tmdb_id:, title: payload["title"], release_date: date.presence, metadata:)
      end
    rescue ActiveRecord::RecordNotUnique => error
      constraint = error.cause&.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      raise unless constraint == "index_films_on_tmdb_id"
      Film.find_by(tmdb_id:) || raise(error)
    rescue ActiveRecord::RecordInvalid => error
      raise unless error.record.is_a?(Film) && error.record.errors.details == { tmdb_id: [ { error: :taken, value: tmdb_id } ] }
      Film.find_by(tmdb_id:) || raise(error)
    end
  end
end
