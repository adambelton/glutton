require "test_helper"
require_relative "../../../support/tmdb_http"
require_relative "../../../support/film_import_sources"

class Registry::WikipediaImportSourcesTest < ActiveSupport::TestCase
  include TmdbHttp
  include FilmImportSources

  class RoutedHttp < TmdbHttp::Connection
    attr_reader :visited

    def initialize(routes:)
      @routes, @visited = routes, []
      super(response: nil)
    end

    def new(host, port)
      @host, @port = host, port
      self
    end

    def request(request)
      @visited << [ @host, request ]
      uri = URI.parse(request.path)
      parameters = URI.decode_www_form(uri.query.to_s).to_h
      payload = @routes.call(@host, uri.path, parameters)
      yield TmdbHttp::Response.new(code: 200, body: JSON.generate(payload))
    end
  end

  def page_query
    { "query" => {
      "rightsinfo" => { "text" => "CC BY-SA 4.0", "url" => "https://creativecommons.org/licenses/by-sa/4.0/" },
      "pages" => [ { "pageid" => 10, "ns" => 0, "title" => "Alien (film)", "pageprops" => { "wikibase_item" => "Q1" },
        "revisions" => [ { "revid" => 20, "timestamp" => "2026-11-01T12:00:00Z" } ] } ]
    } }
  end

  def article_html
    <<~HTML
      <div class="mw-parser-output">
        <p>Alien is a film.</p>
        <table><tr><td><p>Infobox noise.</p></td></tr></table>
        <div class="hatnote"><p>Unrelated film.</p></div>
        <div class="mw-heading"><h2>Plot<span class="mw-editsection">[edit]</span></h2></div>
        <p>The <i>crew</i> encounters&nbsp; a threat.<sup class="reference">[1]</sup></p>
        <h3>Ending</h3><p>A survivor escapes.</p>
        <h2>Production</h2><p>The director intended a frightening effect.</p>
        <h2>Reception</h2><p>A critic described it as “terrifying”.</p>
        <blockquote><p>Detached quotation.</p></blockquote>
        <h2>Cast</h2><p>Cast listing.</p>
        <h2>References</h2><p>Reference noise.</p>
      </div>
    HTML
  end

  test "selected search result follows external IDs and exact Wikipedia revision in one import" do
    http = RoutedHttp.new(routes: ->(host, path, parameters) {
      case [ host, path ]
      when [ "api.themoviedb.org", "/3/search/movie" ]
        { "page" => 1, "total_pages" => 1, "total_results" => 2,
          "results" => [ { "id" => 349, "title" => "Alien", "release_date" => "2000-01-01" },
            { "id" => 348, "title" => "Alien", "release_date" => "1979-05-25" } ] }
      when [ "api.themoviedb.org", "/3/movie/348" ]
        { "id" => 348, "title" => "Alien", "release_date" => "1979-05-25", "imdb_id" => "tt0078748" }
      when [ "api.themoviedb.org", "/3/movie/348/external_ids" ]
        { "id" => 348, "wikidata_id" => "Q1" }
      when [ "www.wikidata.org", "/w/api.php" ]
        assert_equal "Q1", parameters.fetch("ids")
        assert_equal "enwiki", parameters.fetch("sitefilter")
        { "entities" => { "Q1" => { "id" => "Q1", "sitelinks" => { "enwiki" => { "site" => "enwiki", "title" => "Alien (film)" } } } } }
      when [ "en.wikipedia.org", "/w/api.php" ]
        if parameters.fetch("action") == "query"
          assert_equal "Alien (film)", parameters.fetch("titles")
          assert_equal "rightsinfo", parameters.fetch("siprop")
          page_query
        else
          assert_equal "20", parameters.fetch("oldid")
          assert_not parameters.key?("page")
          { "parse" => { "pageid" => 10, "revid" => 20, "text" => article_html } }
        end
      else
        raise "Unexpected request"
      end
    })
    tmdb_client = Registry::Sources::TmdbClient.new(token: "test-token", http_class: http)
    found = Registry::Sources::SearchTmdbFilms.call(query: "Alien", client: tmdb_client)
    assert_not Registry::Film.exists?(tmdb_id: 348)
    selected = found.fetch(:candidates).last
    film = assert_difference("Registry::Film.count", 1) do
      Registry::CatalogueMaintenance::ImportFilm.call(tmdb_id: selected.fetch(:tmdb_id), tmdb_client:,
        wikidata_client: Registry::Sources::WikidataClient.new(http_class: http), wikipedia_client: Registry::Sources::WikipediaClient.new(http_class: http))
    end
    assert film.reload.has_source_context?
    assert_equal 348, film.tmdb_id
    assert_equal "Q1", film.wikidata_id
    assert_not Registry::Film.exists?(tmdb_id: 349)
    context = film.wikipedia_context
    assert_equal "en", context.fetch("language")
    assert_equal [ 10, 20, "Q1", "CC BY-SA 4.0" ], context.values_at("page_id", "revision_id", "wikidata_id") + [ context.dig("license", "name") ]
    assert_equal "https://en.wikipedia.org/w/index.php?oldid=20", context.fetch("revision_url")
    assert_equal [
      [ nil, "Alien is a film." ], [ "Plot", "The crew encounters a threat." ], [ "Plot / Ending", "A survivor escapes." ],
      [ "Production", "The director intended a frightening effect." ], [ "Reception", "A critic described it as “terrifying”." ]
    ], context.fetch("source_paragraphs").map { |paragraph| paragraph.values_at("section", "text") }
    assert_equal %w[P1 P2 P3 P4 P5], context.fetch("source_paragraphs").map { |paragraph| paragraph.fetch("id") }
    http.visited.each do |host, request|
      assert_equal ProviderRequest::USER_AGENT, request["User-Agent"]
      assert_nil request["Authorization"] unless host == "api.themoviedb.org"
    end
    assert_equal 6, http.visited.size
  end

  test "Wikidata cannot substitute a different entity or an absent English article" do
    [ {}, { "entities" => [] }, { "entities" => { "Q1" => { "id" => "Q2" } } },
      { "entities" => { "Q1" => { "id" => "Q1", "sitelinks" => {} } } },
      { "entities" => { "Q1" => { "id" => "Q1", "sitelinks" => { "enwiki" => { "site" => "dewiki", "title" => "Wrong" } } } } } ].each do |payload|
      http = Connection.new(response: Response.new(code: 200, body: payload.to_json))
      assert_raises(Registry::Errors::ImportIncomplete) { Registry::Sources::WikidataClient.new(http_class: http).wikipedia_title(wikidata_id: "Q1") }
      assert_equal 1, http.requests.size
    end
  end

  test "Wikipedia rejects disambiguation missing mismatched and incomplete identity metadata" do
    [ ->(q) { q["query"]["pages"].first["pageprops"]["disambiguation"] = "" },
      ->(q) { q["query"]["pages"].first["pageprops"]["wikibase_item"] = "Q2" },
      ->(q) { q["query"]["pages"].first["missing"] = true },
      ->(q) { q["query"]["pages"].first["ns"] = 1 },
      ->(q) { q["query"]["pages"].first["revisions"] = [] },
      ->(q) { q["query"].delete("rightsinfo") },
      ->(q) { q["query"]["rightsinfo"]["url"] = "javascript:bad" } ].each do |change|
      query = page_query
      change.call(query)
      http = Connection.new(response: Response.new(code: 200, body: query.to_json))
      assert_raises(Registry::Errors::ImportIncomplete) do
        Registry::Sources::WikipediaClient.new(http_class: http).context(title: "Alien (film)", wikidata_id: "Q1", tmdb_id: 348)
      end
      assert_equal 1, http.requests.size
    end
  end

  test "a revision response cannot substitute page revision or usable source content" do
    [ { "pageid" => 11, "revid" => 20, "text" => article_html },
      { "pageid" => 10, "revid" => 21, "text" => article_html },
      { "pageid" => 10, "revid" => 20, "text" => "<div>Invalid body</div>" },
      { "pageid" => 10, "revid" => 20, "text" => '<div class="mw-parser-output"><p>Only a title.</p></div>' } ].each do |parsed|
      http = RoutedHttp.new(routes: ->(_host, _path, parameters) { parameters["action"] == "query" ? page_query : { "parse" => parsed } })
      assert_raises(Registry::Errors::ImportIncomplete) do
        Registry::Sources::WikipediaClient.new(http_class: http).context(title: "Alien (film)", wikidata_id: "Q1", tmdb_id: 348)
      end
    end
  end

  test "redirect-normalised page title is accepted only with the same identity and revision" do
    query = page_query
    query["query"]["redirects"] = [ { "from" => "Alien", "to" => "Alien (film)" } ]
    http = RoutedHttp.new(routes: ->(_host, _path, parameters) {
      parameters["action"] == "query" ? query : { "parse" => { "pageid" => 10, "revid" => 20, "text" => article_html } }
    })
    context = Registry::Sources::WikipediaClient.new(http_class: http).context(title: "Alien", wikidata_id: "Q1", tmdb_id: 348)
    assert_equal "Alien (film)", context.fetch("title")
    assert Registry::Sources::WikipediaContext.usable?(context, tmdb_id: 348)
  end

  test "source HTTP failures are bounded sanitised and never retried" do
    [ [ :wikidata, ->(http) { Registry::Sources::WikidataClient.new(http_class: http).wikipedia_title(wikidata_id: "Q1") } ],
      [ :wikipedia, ->(http) { Registry::Sources::WikipediaClient.new(http_class: http).context(title: "Alien", wikidata_id: "Q1", tmdb_id: 348) } ] ].each do |provider, fetch|
      { 301 => :http_error, 401 => :authentication, 403 => :authentication, 404 => :not_found, 429 => :rate_limited, 500 => :http_error }.each do |code, reason|
        http = Connection.new(response: Response.new(code:, body: "private-response"))
        error = assert_raises(Registry::Errors::ImportIncomplete) { fetch.call(http) }
        assert_equal [ provider, reason ], [ error.stage, error.reason ]
        assert_equal 1, http.requests.size
        assert_nil error.cause
        refute_includes error.full_message, "private-response"
        assert_equal [ 5, 10, 10, 0 ], [ http.open_timeout, http.read_timeout, http.write_timeout, http.max_retries ]
        assert http.use_ssl
      end
    end
    [ Net::OpenTimeout, SocketError, EOFError, OpenSSL::SSL::SSLError ].each do |failure|
      http = Connection.new(response: nil, failure: failure.new("private-response"))
      error = assert_raises(Registry::Errors::ImportIncomplete) { Registry::Sources::WikipediaClient.new(http_class: http).context(title: "Alien", wikidata_id: "Q1", tmdb_id: 348) }
      assert_equal(failure <= Timeout::Error ? :timeout : :transport, error.reason)
      assert_nil error.cause
      refute_includes error.full_message, "private-response"
    end
  end

  test "Wikidata owns Wikimedia API error interpretation" do
    { "maxlag" => :rate_limited, "ratelimited" => :rate_limited, "missingtitle" => :invalid_response }.each do |code, reason|
      http = Connection.new(response: Response.new(code: 200, body: { error: { code: } }.to_json))
      error = assert_raises(Registry::Errors::ImportIncomplete) do
        Registry::Sources::WikidataClient.new(http_class: http).wikipedia_title(wikidata_id: "Q1")
      end
      assert_equal [ :wikidata, reason ], [ error.stage, error.reason ]
    end
  end

  test "JSON API errors and streaming size limits cannot become source data" do
    [ "broken", "null", "[]", '{"error":{"code":"missingtitle"}}', '{"error":{"code":"maxlag"}}' ].each do |body|
      http = Connection.new(response: Response.new(code: 200, body:))
      error = assert_raises(Registry::Errors::ImportIncomplete) { Registry::Sources::WikipediaClient.new(http_class: http).context(title: "Alien", wikidata_id: "Q1", tmdb_id: 348) }
      assert_equal(body.include?("maxlag") ? :rate_limited : :invalid_response, error.reason)
    end
    [ Response.new(code: 200, body: "{}", headers: { "Content-Length" => "9000000" }),
      Response.new(code: 200, body: [ "a" * 4.megabytes, "b" * 5.megabytes ]) ].each do |response|
      http = Connection.new(response:)
      error = assert_raises(Registry::Errors::ImportIncomplete) { Registry::Sources::WikipediaClient.new(http_class: http).context(title: "Alien", wikidata_id: "Q1", tmdb_id: 348) }
      assert_equal :too_large, error.reason
    end
    http = Connection.new(response: Response.new(code: 200, body: "a" * 3.megabytes))
    error = assert_raises(Registry::Errors::TmdbUnavailable) { Registry::Sources::TmdbClient.new(token: "test", http_class: http).movie(tmdb_id: 348) }
    assert_equal :too_large, error.reason
  end
end
