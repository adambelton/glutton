require "test_helper"
require_relative "../support/film_import_sources"

class LibraryFilmSearchTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include FilmImportSources

  setup do
    @user = Identity::UserGuest.create!
    @authentication = Identity::Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
    @controller_class = Library::FilmSearchController
    @forgery = @controller_class.allow_forgery_protection
    @controller_class.allow_forgery_protection = true
    @controller_class::RATE_LIMIT_STORE.clear
  end

  teardown do
    @controller_class.allow_forgery_protection = @forgery
    @controller_class::RATE_LIMIT_STORE.clear
  end

  test "guest searches and adds an existing film then marks it watched" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348)
    with_search do
      get library_path(view: "watched")
      assert_select ".ui-page-heading form[action=?]", library_film_search_path
      assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count" ] do
        get library_film_search_path(query: "Alien")
      end
      assert_response :success
      assert_select "h3", "Alien (1979)"
      assert_select "h3", text: "Alien documentary", count: 0
      assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
        post_selection(library_search_watchlist_path)
      end
      assert_redirected_to library_film_search_path(query: "Alien", page: 1)
      entry = Library::LibraryFilm.find_by!(user: @user, film:)
      assert_not entry.watched?
      follow_redirect!
      assert_select "form[action=?]", library_search_watchlist_path, count: 0
      post_selection(library_search_move_to_watched_path)
      assert_redirected_to library_film_search_path(query: "Alien", page: 1)
      assert entry.reload.watched?
      follow_redirect!
      assert_select "form[action=?]", library_search_watched_path, count: 0
    end
  end

  test "marking a missing film watched imports both sources and queues assignment" do
    with_search do
      get library_film_search_path(query: "Alien")
      with_import_sources do
        assert_enqueued_jobs(1, only: Registry::AssignInitialFilmQualitiesJob) do
          assert_difference [ "Registry::Film.count", "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ], 1 do
            post_selection(library_search_watched_path)
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

  test "missing source prevents the Library action" do
    with_search do
      get library_film_search_path(query: "Alien")
      missing = ->(tmdb_id:) { raise Registry::Errors::TmdbNotFound }
      replace_method(Registry::Sources::TmdbClient, :movie, missing) do
        assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
          post_selection(library_search_watchlist_path)
        end
      end
      follow_redirect!
      assert_select '[role="alert"]', /could not be imported/
    end
  end

  test "stale search action leaves the existing Library entry unchanged" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348)
    with_search do
      get library_film_search_path(query: "Alien")
      entry = Library::CollectionManagement::AddToWatched.call(user_id: @user.id, film_id: film.id)
      assert_no_difference [ "Library::LibraryFilm.count", "DomainEvents::DomainEvent.count" ] do
        post_selection(library_search_watchlist_path)
      end
      assert entry.reload.watched?
      follow_redirect!
      assert_select '[role="alert"]', I18n.t("library.search.action_unavailable")
    end
  end

  test "malformed selections and signed out requests leave the catalogue untouched" do
    with_search do
      get library_film_search_path(query: "Alien")
      token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
      assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count" ] do
        post library_search_watchlist_path, params: { query: "Alien", tmdb_id: [], authenticity_token: token }
        assert_response :bad_request
        Identity::Session.revoke(id: @authentication.id)
        post library_search_watchlist_path, params: { query: "Alien", tmdb_id: "348", authenticity_token: token }
        assert_response :unauthorized
        get library_film_search_path(query: "Alien")
        assert_redirected_to new_session_path
      end
    end
  end

  test "search stops before TMDB when the request limit is reached" do
    with_search do
      30.times { get library_film_search_path(query: "Alien") }
    end
    provider_call = ->(**) { flunk "The limited request reached TMDB" }
    replace_method(Registry::Sources::TmdbClient, :search, provider_call) do
      get library_film_search_path(query: "Alien")
      assert_response :too_many_requests
    end
  end

  private

  def post_selection(path)
    form = Nokogiri::HTML(response.body).at_css("form[action='#{path}']")
    fields = form.css("input[type=hidden]").to_h { |field| [ field["name"], field["value"] ] }
    post path, params: fields
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
