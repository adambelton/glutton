require "net/http"
require "json"
require "timeout"

module FilmKnowledge
  class ProviderRequest
    USER_AGENT = "Glutton/0.1 (https://github.com/adambelton/glutton)".freeze

    class Error < StandardError
      attr_reader :reason

      def initialize(reason:)
        @reason = reason
        super("HTTP JSON request failed (#{reason})")
      end
    end

    class UniqueJsonObject < Hash
      def []=(key, value)
        raise JSON::ParserError, "Duplicate JSON key" if key?(key)
        super
      end
    end

    def initialize(host:, maximum_bytes:, http_class: Net::HTTP, read_timeout: 10, request_timeout: 30)
      @host, @maximum_bytes, @http_class = host, maximum_bytes, http_class
      @read_timeout, @request_timeout = read_timeout, request_timeout
    end

    def get(path:, parameters:, headers: {})
      uri = URI::HTTPS.build(host: @host, path:, query: URI.encode_www_form(parameters))
      perform(request: Net::HTTP::Get.new(uri), headers:)
    end

    def post(path:, payload:, headers: {})
      uri = URI::HTTPS.build(host: @host, path:)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      perform(request:, headers:)
    end

    private

    def perform(request:, headers:)
      uri = request.uri
      http = @http_class.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout, http.read_timeout, http.write_timeout, http.max_retries = 5, @read_timeout, 10, 0
      request["Accept"] = "application/json"
      request["User-Agent"] = USER_AGENT
      headers.each { |name, value| request[name] = value }
      body = +""
      Timeout.timeout(@request_timeout) do
        http.start do |connection|
          connection.request(request) do |response|
            case response.code.to_i
            when 200..299
              fail_request(:too_large) if response["Content-Length"].to_i > @maximum_bytes
              response.read_body do |chunk|
                fail_request(:too_large) if body.bytesize + chunk.bytesize > @maximum_bytes
                body << chunk
              end
            when 404 then fail_request(:not_found)
            when 401, 403 then fail_request(:authentication)
            when 429 then fail_request(:rate_limited)
            when 413 then fail_request(:too_large)
            else fail_request(:http_error)
            end
          end
        end
      end
      JSON.parse(body, object_class: UniqueJsonObject)
    rescue JSON::ParserError, EncodingError
      fail_request(:invalid_response)
    rescue Timeout::Error
      fail_request(:timeout)
    rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
      fail_request(:transport)
    end

    def fail_request(reason)
      raise Error.new(reason:), cause: nil
    end
  end
end
