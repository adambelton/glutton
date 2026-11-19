require "test_helper"
require_relative "../support/film_import_sources"

class AdminRegistryFilmImportTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include FilmImportSources

  setup do
    password = "a long test password"
    operator = Identity::UserRegistered.create!(email_address: "registry-import@example.test", password:,
      password_confirmation: password, email_confirmed_at: Time.current, superuser: true)
    sign_in(operator)
    @forgery = [ Registry::FilmSearchController, Registry::FilmsController ].to_h do |controller|
      [ controller, controller.allow_forgery_protection ]
    end
    @forgery.each_key { |controller| controller.allow_forgery_protection = true }
  end

  teardown do
    @forgery.each { |controller, original| controller.allow_forgery_protection = original }
  end

  test "the TMDB frame shows films across genres and their registry status" do
    film = Registry::Film.create!(title: "Alien", tmdb_id: 348)
    with_search do
      get search_admin_films_path, params: { tmdb_query: "Alien", q: "local" }, headers: { "Turbo-Frame" => "admin-tmdb-film-results" }
    end
    assert_response :success
    assert_select ".admin-sidebar", count: 0
    assert_select "turbo-frame[id=admin-tmdb-film-results]" do
      assert_select "li", count: 2
      assert_select "li", text: /Alien documentary/ do
        assert_select "button", text: I18n.t("admin.tmdb.add"), count: 1
      end
      assert_select "li", text: /Alien \(1979\)/ do
        assert_select "a[href=?]", admin_film_path(film), text: I18n.t("admin.tmdb.present")
        assert_select "form", count: 0
      end
      assert_select "a[href=?]", search_admin_films_path(q: "local", tmdb_query: "Alien", tmdb_page: 2)
    end
  end

  test "selecting a missing film imports both sources and queues one Registry assignment" do
    with_search do
      get search_admin_films_path(tmdb_query: "Alien", q: "Alien")
      selection = import_selection
      with_import_sources do
        assert_no_difference "Library::LibraryFilm.count" do
          assert_enqueued_jobs(1, only: Registry::AssignInitialFilmQualitiesJob) do
            assert_difference "Registry::Film.count", 1 do
              post admin_films_path, params: selection
            end
          end
        end
      end
      assert_response :see_other
      assert_redirected_to search_admin_films_path(tmdb_query: "Alien", q: "Alien", tmdb_page: 1)
      film = Registry::Film.find_by!(tmdb_id: 348)
      assert film.has_source_context?
      assert_enqueued_with(job: Registry::AssignInitialFilmQualitiesJob, queue: "registry_assignment", args: [ { film_ids: [ film.id ] } ])
      follow_redirect!
      assert_select "tbody a[href=?]", admin_film_path(film), text: "Alien"
      assert_select "turbo-frame a[href=?]", admin_film_path(film), text: I18n.t("admin.tmdb.present")
    end
  end

  test "a direct import only needs a TMDB ID and returns to the Films collection" do
    with_search { get search_admin_films_path(tmdb_query: "Alien") }
    selection = import_selection.slice("tmdb_id", "authenticity_token")

    with_import_sources do
      assert_enqueued_jobs(1, only: Registry::AssignInitialFilmQualitiesJob) do
        post admin_films_path, params: selection
      end
    end

    assert_response :see_other
    assert_redirected_to admin_films_path
    film = Registry::Film.find_by!(tmdb_id: 348)
    assert film.has_source_context?
    follow_redirect!
    assert_select "tbody a[href=?]", admin_film_path(film)
  end

  test "a stale selection reports a conflict before fetching sources or queueing another job" do
    with_search do
      get search_admin_films_path(tmdb_query: "Alien")
      selection = import_selection
      film = Registry::Film.create!(title: "Alien", tmdb_id: 348)
      replace_method(Registry::Sources::TmdbClient, :movie, ->(**) { flunk "An existing film reached TMDB" }) do
        assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
          assert_no_difference [ "Registry::Film.count", "Library::LibraryFilm.count" ] do
            post admin_films_path, params: selection
          end
        end
      end
      assert_response :see_other
      follow_redirect!
      assert_select '[role="alert"]', I18n.t("admin.tmdb.already_present")
      assert_select "turbo-frame a[href=?]", admin_film_path(film), text: I18n.t("admin.tmdb.present")
    end
  end

  test "unavailable source data leaves no partial film or assignment" do
    with_search do
      get search_admin_films_path(tmdb_query: "Alien")
      selection = import_selection
      replace_method(Registry::Sources::TmdbClient, :movie, ->(**) { raise Registry::Errors::TmdbNotFound }) do
        assert_no_enqueued_jobs(only: Registry::AssignInitialFilmQualitiesJob) do
          assert_no_difference "Registry::Film.count" do
            post admin_films_path, params: selection
          end
        end
      end
      follow_redirect!
      assert_select '[role="alert"]', /could not be imported/
    end
  end

  test "TMDB search errors stay inside the results frame" do
    replace_method(Registry::Sources::TmdbClient, :search, ->(**) { raise Registry::Errors::TmdbUnavailable.new(reason: :http_error) }) do
      get search_admin_films_path, params: { tmdb_query: "Alien" }, headers: { "Turbo-Frame" => "admin-tmdb-film-results" }
    end
    assert_response :service_unavailable
    assert_select 'turbo-frame [role="alert"]', I18n.t("admin.tmdb.unavailable")
  end

  test "ordinary users and malformed selections are rejected before catalogue changes" do
    with_search { get search_admin_films_path(tmdb_query: "Alien") }
    selection = import_selection
    replace_method(Registry::Sources::TmdbClient, :movie, ->(**) { flunk "An invalid selection reached TMDB" }) do
      post admin_films_path, params: selection.merge("tmdb_id" => [ "348" ])
      assert_response :bad_request
    end

    cookies.delete("session_id")
    get search_admin_films_path(tmdb_query: "Alien")
    assert_redirected_to new_session_path
    sign_in(Identity::UserGuest.create!)
    replace_method(Registry::Sources::TmdbClient, :search, ->(**) { flunk "A guest request reached TMDB" }) do
      get search_admin_films_path(tmdb_query: "Alien")
      assert_response :forbidden
    end
    token = Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
    assert_no_difference "Registry::Film.count" do
      post admin_films_path, params: selection.merge("authenticity_token" => token)
    end
    assert_response :forbidden
  end

  private

  def sign_in(user)
    session = Identity::Session.create!(user:)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: session.id, user_id: user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def import_selection
    form = Nokogiri::HTML(response.body).at_css("turbo-frame form")
    form.css("input[type=hidden]").to_h { |field| [ field["name"], field["value"] ] }
  end

  def with_search(&block)
    search = ->(query:, page:, primary_release_year:) do
      assert_equal "Alien", query
      { "page" => page, "total_pages" => 2, "total_results" => 3, "results" => [
        { "id" => 348, "title" => "Alien", "release_date" => "1979-05-25", "genre_ids" => [ 27 ] },
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
