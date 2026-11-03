require "net/http"

module TmdbHttp
  class Response
    attr_reader :code, :body

    def initialize(code:, body:, headers: {})
      @code, @body, @headers = code.to_s, body, headers
    end

    def [](header)
      @headers[header]
    end

    def read_body
      Array(body).each { |chunk| yield chunk.to_s }
    end
  end

  class Connection
    attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout, :max_retries
    attr_reader :requests, :host, :port

    def initialize(response:, failure: nil)
      @response, @failure, @requests = response, failure, []
    end

    def new(host, port)
      @host, @port = host, port
      self
    end

    def start
      yield self
    end

    def request(request)
      @requests << request
      raise @failure if @failure
      yield @response if block_given?
      @response
    end
  end

  def fake_http(code: 200, body: '{"id":348,"title":"Alien"}', failure: nil, token: "fake-test-token")
    response = Response.new(code:, body:)
    @http = Connection.new(response:, failure:)
    FilmKnowledge::TmdbClient.new(token:, http_class: @http)
  end
end
