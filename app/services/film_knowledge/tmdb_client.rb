require "net/http"
require "json"

module FilmKnowledge
  class TmdbClient
    def self.movie(tmdb_id:)
      new(token: ENV["TMDB_API_READ_ACCESS_TOKEN"]).movie(tmdb_id:)
    end

    def initialize(token:, http_class: Net::HTTP)
      @token = token
      @http_class = http_class
    end

    def movie(tmdb_id:)
      raise InvalidTmdbId, "TMDB ID must be a positive Integer" unless tmdb_id.is_a?(Integer) && tmdb_id.positive?
      unless @token.is_a?(String) && @token.present? && !@token.match?(/[\r\n]/)
        raise TmdbConfigurationError, "Configure TMDB_API_READ_ACCESS_TOKEN"
      end

      uri = URI("https://api.themoviedb.org/3/movie/#{tmdb_id}?language=en-US")
      http = @http_class.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10
      http.write_timeout = 10
      http.max_retries = 0
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"
      response = http.start { |connection| connection.request(request) }

      case response.code.to_i
      when 200..299
        payload = JSON.parse(response.body.to_s)
        raise InvalidTmdbResponse, "TMDB returned invalid movie data" unless payload.is_a?(Hash)
        payload
      when 404
        raise TmdbNotFound, "TMDB movie was not found"
      when 401, 403
        raise TmdbUnavailable.new(reason: :authentication)
      when 429
        raise TmdbUnavailable.new(reason: :rate_limited)
      else
        raise TmdbUnavailable.new(reason: :http_error)
      end
    rescue JSON::ParserError
      raise InvalidTmdbResponse, "TMDB returned invalid JSON", cause: nil
    rescue Timeout::Error
      raise TmdbUnavailable.new(reason: :timeout), cause: nil
    rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
      raise TmdbUnavailable.new(reason: :transport), cause: nil
    end
  end
end
