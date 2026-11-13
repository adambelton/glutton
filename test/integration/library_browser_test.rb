require "test_helper"

class LibraryBrowserTest < ActionDispatch::IntegrationTest
  setup do
    @user = Identity::UserGuest.create!
    bind_user
  end

  def bind_user
    @authentication = Identity::Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def entry(watched: true, user: @user, title: "A film", **attributes)
    Library::LibraryFilm.create!(watched:, user:, film: Registry::Film.create!(title:, **attributes))
  end

  test "two views isolate membership and owner and default to watchlist without writes" do
    watchlist = entry(watched: false, title: "Watchlist film", tmdb_metadata: { details: { poster_path: "/watchlist.jpg" } })
    watched = entry(title: "Watched film")
    entry(user: Identity::UserGuest.create!, title: "Private film")
    assert_no_difference [ "Library::LibraryFilm.count", "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count", "Identity::User.count", "Identity::Session.count" ] do
      get library_path(user_id: Identity::UserGuest.last.id)
      assert_response :success
      assert_select "h3", text: watchlist.film.title, count: 1
      assert_select "h3", count: 1
      assert_select 'nav.library-tabs a[aria-current="page"][href=?]', library_path(view: "watchlist"), text: "Watchlist"
      assert_select ".library-films img[src=?]", "https://image.tmdb.org/t/p/w500/watchlist.jpg"
      { Library::CollectionManagement::Browse::Views::WATCHED => watched }.each do |view, row|
        get library_path(view:)
        assert_select "h3", text: row.film.title, count: 1
        assert_select "h3", count: 1
        assert_select 'nav.library-tabs a[aria-current="page"][href=?]', library_path(view:), text: "Watched"
        assert_select ".library-films .poster-placeholder"
      end
      assert_select "main form[action=?] button.library-rating-icon", new_rating_path, count: 1
    end
  end

  test "only same-owner actual ratings count and committed ratings are visible without delivery" do
    rows = 5.times.map { |i| entry(title: "Film #{i}") }
    rows.drop(1).zip([ [ false, false ], [ true, false ], [ false, true ], [ true, true ] ]).each do |row, (suppressed, dismissed)|
      Ratings::RatingFilm.create!(user: @user, film: row.film, suppressed:, dismissed:)
    end
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: rows.first.film)
    foreign.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
    assert_select ".library-film p", text: "Awaiting rating", count: 0
    assert_select "main form[action=?] button.library-rating-icon", new_rating_path, count: 5
    assert_select 'form[action=?] input[name="film_id"][value=?]', new_rating_path, rows.first.film_id.to_s

    row = Ratings::RatingFilm.find_by!(user: @user, film: rows.last.film)
    Ratings::RatingRecording::SubmitRating.call(user_id: @user.id, rating_film_id: row.id, value: Ratings::Rating::Values::BRILLIANT)
    absent = Ratings::RatingFilm.create!(user: @user, film: Registry::Film.create!(title: "Not in Library"))
    absent.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
    assert_select ".library-film p", text: "Rated", count: 0
    assert_select "main form[action=?] button.library-rating-icon", new_rating_path, count: 4
    assert_select "h3", count: 5
    assert_select 'form[action=?] input[name="film_id"][value=?]', new_rating_path, rows.last.film_id.to_s, count: 0
  end

  test "watched page rendering keeps database queries bounded as entries grow" do
    entry
    path = library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
    get path # Warm lazy Rails lookups before measuring requests.
    count_queries = lambda do
      count = 0
      subscriber = ->(_name, _start, _finish, _id, payload) do
        count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
      end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { get path }
      assert_response :success
      count
    end

    single_entry_queries = count_queries.call
    assert_operator single_entry_queries, :>, 0
    10.times { entry }
    assert_equal single_entry_queries, count_queries.call
    assert_select ".library-rating-icon", count: 11
  end

  test "links admit missing candidates reuse suppressed dismissed candidates and reject stale rated links" do
    [ nil, [ true, false ], [ false, true ], [ true, true ] ].each do |flags|
      row = entry
      candidate = Ratings::RatingFilm.create!(user: @user, film: row.film, suppressed: flags.first, dismissed: flags.last) if flags
      get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
      assert_select 'form[action=?][method="get"] input[name="film_id"][value=?]', new_rating_path, row.film_id.to_s
      link = new_rating_path(film_id: row.film_id)
      assert_difference "Ratings::RatingFilm.count", flags ? 0 : 1 do
        get link
        assert_response :success
      end
      candidate ||= Ratings::RatingFilm.find_by!(user: @user, film: row.film)
      assert_select 'input[name="rating_film_id"][value=?]', candidate.id.to_s
      post rating_path, params: { rating_film_id: candidate.id, value: Ratings::Rating::Values::PRETTY_GOOD }
      assert_response :see_other
      get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
      assert_select 'form[action=?] input[name="film_id"][value=?]', new_rating_path, row.film_id.to_s, count: 0
      get link
      assert_response :conflict
    end
  end

  test "pagination is bounded stable and preserves view while tabs reset page" do
    freeze_time do
      rows = 27.times.map { |i| entry(title: "Film #{i}") }
      get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
      assert_select "h3", count: 25
      assert_equal rows.reverse.first(25).map { |row| row.film.title }, Nokogiri::HTML(response.body).css("h3").map(&:text)
      assert_select "a[href=?]", library_path(view: Library::CollectionManagement::Browse::Views::WATCHED, page: 2)
      get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED, page: 2)
      assert_select "h3", count: 2
      assert_select "a[href=?]", library_path(view: Library::CollectionManagement::Browse::Views::WATCHED, page: 1)
      assert_select "a", text: "Next", count: 0
      assert_select "nav.library-tabs" do
        assert_select "a", count: 2
        assert_select "a[href=?]", library_path(view: "watchlist")
        assert_select 'a[aria-current="page"][href=?]', library_path(view: "watched")
      end
      get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED, page: 3)
      assert_select "h3", count: 0
      assert_select "p", "No watched films on this page."
    end
  end

  test "invalid URL parameters fail explicitly" do
    [ "", "watched", "0", "-1", "1.5", "1000000000", [ "1" ], { number: "1" } ].each do |page|
      get library_path, params: { page: }
      assert_response :bad_request
    end
    [ "LibraryFilmWatched", "", [ "watched" ], { name: "watched" } ].each do |view|
      get library_path, params: { view: }
      assert_response :bad_request
    end
  end

  test "rating tags combine using current ratings and include unrated films" do
    revised = entry(title: "Revised film")
    unrated = entry(title: "Unrated film")
    candidate = Ratings::RatingFilm.create!(user: @user, film: revised.film)
    original = candidate.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    Ratings::RatingRecording::ReviseRating.call(user_id: @user.id, rating_film_id: candidate.id,
      previous_rating_id: original.id, value: Ratings::Rating::Values::PRETTY_GOOD)
    foreign = Ratings::RatingFilm.create!(user: Identity::UserGuest.create!, film: unrated.film)
    foreign.submit_rating!(value: Ratings::Rating::Values::BRILLIANT)

    get library_path(view: "watched")
    assert_select ".library-film", count: 2
    assert_select ".library-rating-filters a[href]", count: 5
    assert_select ".library-rating-filters a:nth-last-child(2)", text: "Not Rated"
    assert_select ".library-clear-filters[disabled]:not([data-tooltip])"
    assert_select ".library-rating-filters [data-selected]", count: 0
    get library_path(view: "watched", ratings: %w[brilliant pretty_good not_for_me garbage unrated])
    assert_select ".library-film", count: 2
    assert_select ".library-rating-filters [data-selected]", count: 5

    get library_path(view: "watched", ratings: [ "brilliant" ])
    assert_select ".library-film", count: 0
    get library_path(view: "watched", ratings: [ "brilliant", "unrated" ])
    assert_select ".library-film h3", text: unrated.film.title
    assert_select ".library-film", count: 1
    get library_path(view: "watched", ratings: [ "pretty_good", "unrated" ])
    assert_select ".library-film", count: 2
    assert_select ".library-film h3", text: revised.film.title
    assert_select '.library-rating-filters a[data-selected="true"]', count: 2
    assert_select 'form.library-clear-filters-form[action=?][method="get"]', library_path do
      assert_select 'input[name="view"][value="watched"]'
      assert_select 'button.library-clear-filters[aria-label="Clear selection"][data-tooltip="Clear selection"]:not([disabled])'
    end
  end

  test "titles are escaped dates optional and page is private" do
    entry(title: "<script>alert('film')</script>", release_date: Date.new(2001, 1, 1))
    entry(title: "No release date")
    get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
    assert_select "h3", text: "<script>alert('film')</script> (2001)"
    assert_select "script", text: /alert\('film'\)/, count: 0
    assert_select "h3 .film-year", text: "(2001)", count: 1
    assert_select 'nav[aria-label="Library pages"]'
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
    assert_no_match(/translation missing/i, response.body)
  end

  test "registered access and signed out revoked expired deleted identity outcomes" do
    @user = Identity::UserRegistered.create!(email_address: "library@example.test", password: "a long password phrase",
      password_confirmation: "a long password phrase", email_confirmed_at: Time.current)
    bind_user
    get library_path
    assert_response :success
    Identity::Session.revoke(id: @authentication.id)
    get library_path
    assert_redirected_to new_session_path
    cookies.delete(:session_id)
    assert_no_difference [ "Identity::User.count", "Identity::Session.count" ] do
      get library_path
      assert_redirected_to new_session_path
    end
    @user = Identity::UserGuest.create!
    bind_user
    travel Identity::UserGuest::EXPIRY_DURATION + 1.second do
      get library_path
      assert_redirected_to new_session_path
    end
    bind_user
    # Existing cookie with a deleted owner is a storage fixture for the unimplemented deletion transition.
    @user.update_columns(type: "UserDeleted")
    get library_path
    assert_response :gone
  end
  test "edit links expose latest owner evidence on poster cards without writes" do
    [ @user, Identity::UserRegistered.create!(email_address: "edit-library@example.test",
      password: "long test password", password_confirmation: "long test password",
      email_confirmed_at: Time.current) ].each do |user|
      @user = user
      bind_user
      watched = entry(title: '<script>film</script> "title"')
      unrated = entry
      candidate = Ratings::RatingFilm.create!(user:, film: watched.film, suppressed: true, dismissed: true)
      original = candidate.submit_rating!(value: Ratings::Rating::Values::BRILLIANT, notes: "Original")
      current = Ratings::RatingRecording::ReviseRating.call(user_id: user.id, rating_film_id: candidate.id,
        previous_rating_id: original.id, value: Ratings::Rating::Values::PRETTY_GOOD, notes: "Current")
      edit_link = edit_rating_path(film_id: watched.film_id)
      assert_no_difference [ "Library::LibraryFilm.count", "Ratings::RatingFilm.count", "Ratings::Rating.count", "DomainEvents::DomainEvent.count" ] do
        get library_path(view: Library::CollectionManagement::Browse::Views::WATCHED)
        assert_response :success
        assert_select "form[action=?] button[aria-label=?]", edit_rating_path, "Edit your rating for #{watched.film.title}", count: 1
        assert_select 'form[action=?] button[data-tooltip="Pretty Good · Edit rating"][aria-description="Has rating notes"]', edit_rating_path
        assert_select 'form[action=?] button[data-tooltip="Not Rated · Add rating"][aria-description="No rating notes"]', new_rating_path
        assert_select "script", text: "film", count: 0
        assert_equal "no-store", response.headers["Cache-Control"]
        assert_no_match(/translation missing/i, response.body)
        assert_select 'form[action=?] input[name="film_id"][value=?]', new_rating_path, watched.film_id.to_s, count: 0
        assert_select 'form[action=?] input[name="film_id"][value=?]', new_rating_path, unrated.film_id.to_s
      end
      get edit_link
      assert_response :success
      assert_select 'input[name="previous_rating_id"][value=?]', current.id.to_s
      assert_select "textarea#notes", text: "Current"
      patch rating_path, params: { rating_film_id: candidate.id, previous_rating_id: current.id,
        value: Ratings::Rating::Values::BRILLIANT, notes: "Updated from Library" }
      assert_response :see_other
      get library_path(view: "watched")
      assert_select 'form[action=?] input[name="film_id"][value=?]', edit_rating_path, watched.film_id.to_s
      get edit_link
      assert_response :success
      assert_select "textarea#notes", text: "Updated from Library"
      assert_select 'input[name="previous_rating_id"][value=?]', candidate.ratings.order(:id).last.id.to_s
      assert_equal "Original", original.notes

      Ratings::RatingRecording::ReviseRating.call(user_id: user.id, rating_film_id: candidate.id,
        previous_rating_id: candidate.ratings.order(:id).last.id, value: Ratings::Rating::Values::BRILLIANT, notes: nil)
      get library_path(view: "watched")
      assert_select 'form[action=?] button[data-tooltip="Brilliant · Edit rating"][aria-description="No rating notes"]', edit_rating_path
    end
  end

  test "unwatched library pages do not offer editing even when ratings exist" do
    row = entry(watched: false)
    Ratings::RatingFilm.create!(user: @user, film: row.film).submit_rating!(value: Ratings::Rating::Values::BRILLIANT)
    get library_path
    assert_response :success
    assert_select "form[action=?] button.library-rating-icon", edit_rating_path, count: 0
  end
end
