require "test_helper"
require_relative "../support/film_import_sources"

class LibraryTmdbFilmSearchTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include FilmImportSources

  setup do
    @user = Identity::UserGuest.create!
    @authentication = Identity::Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
    @forgery = [ Library::TmdbFilmSearchController, LibraryController ].to_h do |controller|
      [ controller, controller.allow_forgery_protection ]
    end
    @forgery.each_key { |controller| controller.allow_forgery_protection = true }
    clear_rate_limits
  end

  teardown do
    @forgery.each { |controller, original| controller.allow_forgery_protection = original }
    clear_rate_limits
  end

  test "TMDB pages carry horror matches across provider pages and preserve the batch after an action" do
    tmdb_search = ->(query:, page:, **) do
      ids = { 1 => (348..351).to_a, 2 => [], 3 => (352..357).to_a }.fetch(page)
      results = ids.map { |id| { "id" => id, "title" => "Film #{id}", "genre_ids" => [ 27 ] } }
      results << { "id" => 99, "title" => "Unrelated result", "genre_ids" => [ 99 ] }
      { "page" => page, "total_pages" => 3, "total_results" => 13, "results" => results }
    end
    Registry::Film.create!(title: "Film 353", tmdb_id: 353)

    replace_method(Registry::Sources::TmdbClient, :search, tmdb_search) do
      get library_tmdb_film_search_path(query: "Film")
      assert_equal (348..352).map { |id| "Film #{id}" }, css_select(".film-search-results h3").map(&:text)
      next_path = css_select(".library-pagination a").sole["href"]
      get next_path
      assert_equal (353..357).map { |id| "Film #{id}" }, css_select(".film-search-results h3").map(&:text)
      assert_select ".library-pagination a", text: I18n.t("library.browser.previous"), count: 1
      assert_select ".library-pagination a", text: I18n.t("library.browser.next"), count: 0

      post_selection(library_tmdb_search_watchlist_path)
      assert_redirected_to next_path
      follow_redirect!
      assert_select ".film-search-results li", text: /Film 353.*#{I18n.t('library.search.in_watchlist')}/
      get css_select(".library-pagination a").sole["href"]
      assert_equal (348..352).map { |id| "Film #{id}" }, css_select(".film-search-results h3").map(&:text)
    end
  end

  test "guest can add a film from TMDB and sees status without actions for Library entries" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348)
    with_search do
      get library_path(view: "watched")
      assert_select ".ui-page-heading form[action=?]", library_tmdb_film_search_path
      assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count" ] do
        get library_tmdb_film_search_path(query: "Alien")
      end
      assert_response :success
      assert_select "h3", "Alien (1979)"
      assert_select "h3", text: "Alien documentary", count: 0
      assert_select "form[action=?]", library_tmdb_search_watched_path, count: 1
      assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
        post_selection(library_tmdb_search_watchlist_path)
      end
      assert_redirected_to library_tmdb_film_search_path(query: "Alien", page: 1)
      entry = Library::LibraryFilm.find_by!(user: @user, film:)
      assert_not entry.watched?
      follow_redirect!
      assert_select ".film-search-results li", count: 1 do
        assert_select "p", text: I18n.t("library.search.in_watchlist")
        assert_select "button, form", count: 0
      end

      Library::CollectionManagement::MoveWatchlistToWatched.call(user_id: @user.id, library_film_id: entry.id)
      get library_tmdb_film_search_path(query: "Alien")
      assert_select ".film-search-results li", count: 1 do
        assert_select "p", text: I18n.t("library.search.in_watched")
        assert_select "button, form", count: 0
      end
    end
  end

  test "marking a missing film watched imports both sources and queues assignment" do
    with_search do
      get library_tmdb_film_search_path(query: "Alien")
      with_import_sources do
        assert_enqueued_jobs(1, only: Registry::AssignInitialFilmQualitiesJob) do
          assert_difference [ "Registry::Film.count", "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ], 1 do
            post_selection(library_tmdb_search_watched_path)
          end
        end
      end
      assert_response :see_other
      film = Registry::Film.find_by!(tmdb_id: 348)
      assert film.has_source_context?
      assert Library::LibraryFilm.find_by!(user: @user, film:).watched?
      assert_enqueued_with(job: Registry::AssignInitialFilmQualitiesJob, queue: "registry_assignment", args: [ { film_ids: [ film.id ] } ])
    end
  end

  test "a verified film with no Wikidata link can be added to Watchlist" do
    without_wikidata_link = ->(tmdb_id:) { { "id" => tmdb_id, "wikidata_id" => nil } }
    with_search do
      get library_tmdb_film_search_path(query: "Alien")
      with_import_sources do
        replace_method(Registry::Sources::TmdbClient, :external_ids, without_wikidata_link) do
          replace_method(Registry::Sources::WikidataClient, :wikipedia_title, ->(**) { flunk "Wikidata was queried without an ID" }) do
            assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
              assert_difference [ "Registry::Film.count", "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ], 1 do
                post_selection(library_tmdb_search_watchlist_path)
              end
            end
          end
        end
      end
      assert_redirected_to library_tmdb_film_search_path(query: "Alien", page: 1)
      film = Registry::Film.find_by!(tmdb_id: 348)
      assert_equal "Alien", film.tmdb_metadata.dig("details", "title")
      assert_empty film.wikipedia_context
      assert_nil film.wikidata_id
      assert_not film.has_source_context?
      assert_not Library::LibraryFilm.find_by!(user: @user, film:).watched?
      assert_equal film.id, Registry::CatalogueMaintenance::FindOrImportTmdbFilm.call(tmdb_id: 348).id
    end
  end

  test "a verified film without an English Wikipedia link retains its Wikidata ID" do
    no_english_article = ->(wikidata_id:) { raise Registry::Errors::ImportIncomplete.new(stage: :wikidata, reason: :missing_article) }
    with_search do
      get library_tmdb_film_search_path(query: "Alien")
      with_import_sources do
        replace_method(Registry::Sources::WikidataClient, :wikipedia_title, no_english_article) do
          replace_method(Registry::Sources::WikipediaClient, :context, ->(**) { flunk "Wikipedia was queried without an article" }) do
            assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
              post_selection(library_tmdb_search_watchlist_path)
            end
          end
        end
      end
      assert_redirected_to library_tmdb_film_search_path(query: "Alien", page: 1)
      film = Registry::Film.find_by!(tmdb_id: 348)
      assert_equal "Q1", film.wikidata_id
      assert_empty film.wikipedia_context
      assert_not Library::LibraryFilm.find_by!(user: @user, film:).watched?
    end
  end

  test "a verified film retains limited Wikipedia context for review without queueing assignment" do
    context = wikipedia_context.merge("source_paragraphs" => [ { "id" => "P1", "section" => nil, "text" => "Alien is a film." } ])
    limited_wikipedia = ->(**) { context }
    with_search do
      get library_tmdb_film_search_path(query: "Alien")
      with_import_sources do
        replace_method(Registry::Sources::WikipediaClient, :context, limited_wikipedia) do
          assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
            post_selection(library_tmdb_search_watched_path)
          end
        end
      end
      assert_redirected_to library_tmdb_film_search_path(query: "Alien", page: 1)
      film = Registry::Film.find_by!(tmdb_id: 348)
      assert_equal "Q1", film.wikidata_id
      assert_equal context.fetch("revision_id"), film.wikipedia_context.fetch("revision_id")
      assert_equal "Alien is a film.", film.wikipedia_context.fetch("source_paragraphs").first.fetch("text")
      assert_not film.has_source_context?
      assert Library::LibraryFilm.find_by!(user: @user, film:).watched?
    end
  end

  %i[missing_article invalid_response identity_mismatch timeout].each do |reason|
    test "a verified film can be marked watched when Wikipedia reports #{reason}" do
      incomplete_wikipedia = ->(**) { raise Registry::Errors::ImportIncomplete.new(stage: :wikipedia, reason:) }
      with_search do
        get library_tmdb_film_search_path(query: "Alien")
        with_import_sources do
          replace_method(Registry::Sources::WikipediaClient, :context, incomplete_wikipedia) do
            assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
              assert_difference [ "Registry::Film.count", "Library::LibraryFilm.count" ], 1 do
                post_selection(library_tmdb_search_watched_path)
              end
            end
          end
        end
        assert_redirected_to library_tmdb_film_search_path(query: "Alien", page: 1)
        film = Registry::Film.find_by!(tmdb_id: 348)
        assert_equal "Q1", film.wikidata_id
        assert_empty film.wikipedia_context
        assert Library::LibraryFilm.find_by!(user: @user, film:).watched?
      end
    end
  end

  test "an unverified TMDB movie prevents the Library action" do
    with_search do
      get library_tmdb_film_search_path(query: "Alien")
      missing = ->(tmdb_id:) { raise Registry::Errors::TmdbNotFound }
      replace_method(Registry::Sources::TmdbClient, :movie, missing) do
        assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
          post_selection(library_tmdb_search_watchlist_path)
        end
      end
      follow_redirect!
      assert_select '[role="alert"]', /could not be imported/
    end
  end

  test "stale search action leaves the existing Library entry unchanged" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348)
    with_search do
      get library_tmdb_film_search_path(query: "Alien")
      entry = Library::CollectionManagement::AddToWatched.call(user_id: @user.id, film_id: film.id)
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        post_selection(library_tmdb_search_watchlist_path)
      end
      assert entry.reload.watched?
      follow_redirect!
      assert_select '[role="alert"]', I18n.t("library.search.action_unavailable")
    end
  end

  test "malformed selections and signed out requests leave the catalogue untouched" do
    with_search do
      get library_tmdb_film_search_path(query: "Alien")
      token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
      assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count" ] do
        post library_tmdb_search_watchlist_path, params: { query: "Alien", tmdb_id: [], authenticity_token: token }
        assert_response :bad_request
        Identity::Session.revoke(id: @authentication.id)
        post library_tmdb_search_watchlist_path, params: { query: "Alien", tmdb_id: "348", authenticity_token: token }
        assert_response :unauthorized
        get library_tmdb_film_search_path(query: "Alien")
        assert_redirected_to new_session_path
      end
    end
  end

  test "search stops before TMDB when the request limit is reached" do
    with_search do
      30.times { get library_tmdb_film_search_path(query: "Alien") }
    end
    provider_call = ->(**) { flunk "The limited request reached TMDB" }
    replace_method(Registry::Sources::TmdbClient, :search, provider_call) do
      get library_tmdb_film_search_path(query: "Alien")
      assert_response :too_many_requests
    end
  end

  test "selection rate limit applies across Library actions from search" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348)
    with_search { get library_tmdb_film_search_path(query: "Alien") }
    watchlist = selection_params(library_tmdb_search_watchlist_path)
    watched = selection_params(library_tmdb_search_watched_path)

    10.times do
      post library_tmdb_search_watchlist_path, params: watchlist
      assert_response :see_other
    end
    entry = Library::LibraryFilm.find_by!(user: @user, film:)
    assert_not entry.watched?

    post library_tmdb_search_watched_path, params: watched
    assert_response :too_many_requests
    assert_select '[role="alert"]', I18n.t("library.search.limited")
    assert_not entry.reload.watched?
  end

  private

  def clear_rate_limits
    Library::TmdbFilmSearchController::RATE_LIMIT_STORE.clear
    Library::TmdbFilmSearchController::SELECTION_LIMIT_STORE.clear
  end

  def post_selection(path)
    post path, params: selection_params(path)
  end

  def selection_params(path)
    form = Nokogiri::HTML(response.body).at_css("form[action='#{path}']")
    form.css("input[type=hidden]").to_h { |field| [ field["name"], field["value"] ] }
  end

  def with_search(&block)
    search = ->(**) do
      { "page" => 1, "total_pages" => 1, "total_results" => 2,
        "results" => [
          { "id" => 348, "title" => "Alien", "release_date" => "1979-05-25", "genre_ids" => [ 27, 878 ] },
          { "id" => 349, "title" => "Alien documentary", "genre_ids" => [ 99 ] }
        ] }
    end
    replace_method(Registry::Sources::TmdbClient, :search, search, &block)
  end

  def with_import_sources(&block)
    tmdb = tmdb_source
    replace_method(Registry::Sources::TmdbClient, :movie, tmdb.method(:movie)) do
      replace_method(Registry::Sources::TmdbClient, :external_ids, tmdb.method(:external_ids)) do
        replace_method(Registry::Sources::WikidataClient, :wikipedia_title, wikidata_source.method(:wikipedia_title)) do
          replace_method(Registry::Sources::WikipediaClient, :context, wikipedia_source.method(:context), &block)
        end
      end
    end
  end

  def replace_method(target, name, replacement)
    original = target.method(name)
    target.define_singleton_method(name) { |**kwargs| replacement.call(**kwargs) }
    yield
  ensure
    target.define_singleton_method(name, original)
  end
end
