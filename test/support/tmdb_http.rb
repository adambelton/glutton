require "net/http"

module TmdbHttp
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
      @response
    end
  end

  def fake_http(code: 200, body: '{"id":348,"title":"Alien"}', failure: nil, token: "fake-test-token")
    response = Struct.new(:code, :body).new(code.to_s, body)
    @http = Connection.new(response:, failure:)
    FilmKnowledge::TmdbClient.new(token:, http_class: @http)
  end
end
