require "test_helper"

class LibraryDetailsTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = LibraryController.allow_forgery_protection
    LibraryController.allow_forgery_protection = true
    @user = UserGuest.create!
    @film = Film.create!(title: "A <script>film</script>", release_date: Date.new(2001, 1, 1))
    @entry = LibraryFilmToWatch.create!(user: @user, film: @film)
    bind_user
  end

  teardown do
    LibraryController.allow_forgery_protection = @forgery
  end

  def bind_user
    @authentication = Session.create!(user: @user)
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.signed[:session_id] = { value: { id: @authentication.id, user_id: @user.id } }
    cookies[:session_id] = jar[:session_id]
  end

  def token
    get library_film_path(@entry)
    Nokogiri::HTML(response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def watch(**params)
    post mark_watched_library_film_path(@entry), params: { authenticity_token: token }.merge(params)
  end

  test "collections link to existing entries and present supported actions and information" do
    get library_path
    assert_select "h3 a[href=?]", library_film_path(@entry), text: @film.title
    assert_no_difference [ "LibraryFilm.count", "RatingFilm.count", "Rating.count", "DomainEvent.count" ] do
      get library_film_path(@entry)
      assert_response :success
      assert_select "h1", @film.title
      assert_select "p", "Released in 2001"
      assert_select "form[action=?]", mark_watched_library_film_path(@entry)
      assert_select "form[action=?]", remove_from_watchlist_library_film_path(@entry)
      assert_select "script", text: "film", count: 0
      assert_equal "no-store", response.headers["Cache-Control"]
      assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
      assert_no_match(/translation missing/i, response.body)
      row = LibraryFilmNotInterested.create!(user: @user, film: Film.create!(title: "Other film"))
      get library_film_path(row)
      assert_select "form[action=?]", add_to_watchlist_library_film_path(row)
      assert_select "form[action=?]", remove_from_not_interested_library_film_path(row)
      assert_select "p", text: /Released/, count: 0
      row.destroy!
    end
  end

  test "mark watched retains relationship and redirects to updated detail before event delivery" do
    original_id, original_created_at = @entry.id, @entry.created_at
    other = UserGuest.create!
    assert_difference "DomainEvent.count", 1 do
      assert_no_difference [ "LibraryFilm.count", "RatingFilm.count", "Rating.count" ] do
        watch(user_id: other.id, film_id: Film.create!(title: "Ignore").id, type: "LibraryFilmNotInterested")
      end
    end
    assert_redirected_to library_film_path(@entry)
    assert_response :see_other
    row = LibraryFilm.find(original_id)
    assert_equal original_created_at, row.created_at
    assert_equal @user.id, row.user_id
    event = DomainEvent.joins(:domain_event_stream).find_by!(domain_event_streams: { user_id: @user.id }, name: Library::Events::FILM_MARKED_WATCHED)
    assert_equal @film.id, event.payload.fetch("film_id")
    follow_redirect!
    assert_select '[role="status"]', I18n.t("library.detail.watched")
    assert_select "form", count: 0
    assert_select "a[href=?]", new_rating_path(film_id: @film.id)
    assert_no_difference "DomainEvent.count" do
      watch
      assert_response :conflict
    end
    get new_rating_path(film_id: @film.id)
    assert_response :success
    assert_select "h2", @film.title
  end

  test "watched detail reads same-user actual ratings independent of candidate flags" do
    Library::RecordWatched.call(user_id: @user.id, library_film_id: @entry.id)
    foreign = RatingFilm.create!(user: UserGuest.create!, film: @film)
    foreign.submit_rating!(value: Rating::Values::BRILLIANT)
    row = RatingFilm.create!(user: @user, film: @film, held: true, dismissed: true)
    get library_film_path(@entry)
    assert_select "p", "Awaiting rating"
    assert_select "a[href=?]", new_rating_path(film_id: @film.id)
    row.submit_rating!(value: Rating::Values::BRILLIANT)
    get library_film_path(@entry)
    assert_select "p", "Rated"
    assert_select 'a[href*="rating/new"]', count: 0
  end

  test "registered owner removes entry and stale actions cannot recreate or target its replacement" do
    @user = UserRegistered.create!(email_address: "details@example.test", password: "long test password", password_confirmation: "long test password", email_confirmed_at: Time.current)
    @entry = LibraryFilmToWatch.create!(user: @user, film: @film)
    bind_user
    csrf = token
    assert_difference "LibraryFilm.count", -1 do
      assert_difference "DomainEvent.count", 1 do
        delete remove_from_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      end
    end
    assert_response :see_other
    assert_redirected_to library_path
    follow_redirect!
    assert_select '[role="status"]', I18n.t("library.detail.removed")
    replacement = LibraryFilmToWatch.create!(user: @user, film: @film)
    assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
      get library_film_path(@entry)
      assert_response :not_found
      post mark_watched_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :not_found
      delete remove_from_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :not_found
    end
    assert replacement.reload.can_watch?
  end

  test "invalid foreign and removed IDs are unavailable and unsupported actions conflict" do
    csrf = token
    foreign = LibraryFilmToWatch.create!(user: UserGuest.create!, film: @film)
    [ "0", "-1", "invalid", "999999999", foreign.id ].each do |id|
      get library_film_path(id)
      assert_response :not_found
      post mark_watched_library_film_path(id), params: { authenticity_token: csrf }
      assert_response :not_found
    end
    Library::RecordWatched.call(user_id: @user.id, library_film_id: @entry.id)
    assert_no_difference [ "LibraryFilm.count", "DomainEvent.count" ] do
      delete remove_from_watchlist_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :conflict
    end
  end

  test "csrf and unavailable sessions protect writes without creating replacement identities" do
    csrf = token
    assert_no_difference [ "LibraryFilm.count", "RatingFilm.count", "DomainEvent.count", "User.count" ] do
      post mark_watched_library_film_path(@entry)
      assert_response :unprocessable_entity
      delete remove_from_watchlist_library_film_path(@entry)
      assert_response :unprocessable_entity
      @user.update!(created_at: 25.hours.ago)
      post mark_watched_library_film_path(@entry), params: { authenticity_token: csrf }
      assert_response :unauthorized
      get library_film_path(@entry)
      assert_response :unauthorized
      @user.update!(created_at: Time.current)
      bind_user
      Session.revoke(id: @authentication.id)
      get library_film_path(@entry)
      assert_response :unauthorized
      bind_user
      @user.becomes!(UserDeleted).save!
      get library_film_path(@entry)
      assert_response :gone
    end
  end
end
