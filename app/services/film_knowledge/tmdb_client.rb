require "net/http"
require "json"

module FilmKnowledge
  class TmdbClient
    def self.movie(tmdb_id:)
      new(token: ENV["TMDB_API_READ_ACCESS_TOKEN"]).movie(tmdb_id:)
    end

    def self.external_ids(tmdb_id:)
      new(token: ENV["TMDB_API_READ_ACCESS_TOKEN"]).external_ids(tmdb_id:)
    end

    def self.search(query:, page: 1, primary_release_year: nil)
      new(token: ENV["TMDB_API_READ_ACCESS_TOKEN"]).search(query:, page:, primary_release_year:)
    end

    def initialize(token:, http_class: Net::HTTP)
      @token = token
      @http_class = http_class
    end

    def movie(tmdb_id:)
      raise InvalidTmdbId, "TMDB ID must be a positive Integer" unless tmdb_id.is_a?(Integer) && tmdb_id.positive?
      request_json(path: "/3/movie/#{tmdb_id}", parameters: { language: "en-US" }, movie_not_found: true)
    end

    def external_ids(tmdb_id:)
      raise InvalidTmdbId, "TMDB ID must be a positive Integer" unless tmdb_id.is_a?(Integer) && tmdb_id.positive?
      request_json(path: "/3/movie/#{tmdb_id}/external_ids", parameters: {}, movie_not_found: true)
    end

    def search(query:, page: 1, primary_release_year: nil)
      parameters = TmdbSearchParameters.normalize(query:, page:, primary_release_year:).compact
      parameters.merge!(language: "en-US", include_adult: false)
      request_json(path: "/3/search/movie", parameters:)
    end

    private

    def request_json(path:, parameters:, movie_not_found: false)
      unless @token.is_a?(String) && @token.present? && !@token.match?(/[\r\n]/)
        raise TmdbConfigurationError, "Configure TMDB_API_READ_ACCESS_TOKEN"
      end

      payload = ProviderRequest.new(host: "api.themoviedb.org", maximum_bytes: 2.megabytes, http_class: @http_class)
        .get(path:, parameters:, headers: { "Authorization" => "Bearer #{@token}" })
      raise InvalidTmdbResponse, "TMDB returned invalid movie data" unless payload.is_a?(Hash)
      payload
    rescue ProviderRequest::Error => error
      case error.reason
      when :invalid_response
        raise InvalidTmdbResponse, "TMDB returned invalid JSON or movie data", cause: nil
      when :not_found
        raise TmdbNotFound, "TMDB movie was not found", cause: nil if movie_not_found
        raise TmdbUnavailable.new(reason: :http_error), cause: nil
      else
        raise TmdbUnavailable.new(reason: error.reason), cause: nil
      end
    end
  end
end
